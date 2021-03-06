
# This is the server logic for a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library(shinydashboard)
library(tidyverse)
library(ggplot2)
library(glue)
library(tuneR)
library(seewave)
library(forcats)
library(glue)

# This application has functionalities that wouldn't make sense in
# a web application as such, so I try to set the paths, which maybe
# are inevitable, here as nicely as possible. I don't remember,
# but I think something in tuneR or PraatScript interaction
# didn't like relative paths -- I may be wrong too.

main_folder <- '/Users/niko/github'
praat_stuff_folder <- glue('{main_folder}/praat-stuff')
textgrids_and_wavs <- glue('{main_folder}/testcorpus/praat/0000')
formant_file_path <- glue('{main_folder}/testcorpus/praat/formants.txt')
cog_file_path <- glue('{main_folder}/testcorpus/praat/cog.txt')

# When this value is TRUE, all information is read from files
demonstration_mode = TRUE

# This runs a script that regenerates the Praat formant segments
processing_script = '~/github/praat-stuff/process_praat_segments.sh' 
# Now I just select it and run from here. Could be also a button in GUI
# system(glue('bash {processing_script}'))

# This is probably Mac-specific
setWavPlayer('/usr/bin/afplay')

# This function will be used to open Praat,
# the trick is to open Praat first with one command,
# and then tell it to go to some specific place.
# Not implemented: opening Praat directly from one spot 
open_praat <- function(filename, start, end, praat_executable = '/Applications/Praat.app/Contents/MacOS/Praat'){
  system(glue('open -a {praat_executable}')) # This will not work on Windows…
  system(glue('~/bin/sendpraat_carbon praat "execute {praat_stuff_folder}/open_segment.praat {textgrids_and_wavs}/{filename}.wav {textgrids_and_wavs}/{filename}.TextGrid {start} {end}"'))
}

# This read the formant file. Bit complicated,
# but I didn't get PraatScript to produce something
# more beautiful.
read_formants <- function(formant_file){
  suppressWarnings(read_tsv(formant_file,
                            skip = 1,
                            col_names = c('time', 'type', 'filename', 'token', 'phoneme', 'f1', 'f2', 'f3', 'missing1', 'missing2', 'missing3'))) %>%
    filter(! is.na(token)) %>%
    select(-missing1, -missing2, -missing3) %>%
    select(phoneme, token, type, time, f1, f2, f3, filename) %>%
    filter(! phoneme == 'Avg') %>%
    mutate(id = rep(1:(n()/4), each=4)) %>%
    # gather(variable, value, -(phoneme:token))
    gather(var, val, time:f3) %>%
    #  distinct(id, var, val) %>%
    unite(var2, type, var) %>%
    spread(var2, val) %>%
    arrange(id) %>%
    mutate(before = lag(phoneme)) %>%
    mutate(after = lead(phoneme)) %>%
    filter(phoneme %in% c('a', 'i', 'e', 'u', 'e~', '1', 'o')) %>%
    select(before, phoneme, after, everything(), filename) %>%
    mutate(f1 = as.double(midpoint_f1),
           f2 = as.double(midpoint_f2),
           filename = stringr::str_replace(filename, '.+/', '')) %>%
    mutate(filename = stringr::str_replace(filename, '.wav', '')) %>%
    mutate(duration = as.double(end_time) - as.double(start_time))
}

# For some reason there were just individual points with formant
# below that, and they were spoiling the plots, I just removed them for now
vowels <- read_formants(formant_file = formant_file_path)
vowels <- vowels %>% filter(f1 < 1300)

# readr::write_rds(vowels, 'vowels.rds')

# This is used to set sibilant factor levels
sib_levels <- c('s', 's_j', 'S', 'z', 'z_j', 'Z')

# This reads the cog file
sibilants <- read_tsv(cog_file_path, 
                   col_names = tolower(c("filename", "Token", "Phoneme", "Timepoint", "DurationMS", "HighestFreq", "HighestAmp", "SpectralCOG", "time_start", "time_end")), 
                   col_types = cols(
                     filename = col_character(),
                     token = col_character(),
                     phoneme = col_character(),
                     timepoint = col_integer(),
                     durationms = col_double(),
                     highestfreq = col_double(),
                     highestamp = col_double(),
                     spectralcog = col_double(),
                     time_start = col_double(),
                     time_end = col_double()
                   )) %>%
  mutate(phoneme = factor(phoneme, sib_levels)) %>%
  mutate(filename = stringr::str_extract(filename, '[^/]+(?=.wav$)')) %>%
  filter(! filename == 'kpv_izva20140404IgusevJA-b-373') # this had just horrible segmentation

# Server part starts here

shinyServer(function(input, output) {

  # vowel plot
  
  output$vowel_plot <- renderPlot({
    vowels %>% 
      filter(duration > input$range[1]) %>%
      filter(duration < input$range[2]) %>%
      ggplot(data = .,
             aes(x=f2, y=f1,
                 color = phoneme)) +
      scale_x_reverse(name="F2 (Hz)")+scale_y_reverse(name="F1 (Hz)")+
      geom_point(size = 5) +
      stat_ellipse() +
      #      theme_bw() +
      scale_color_brewer(palette="Accent")
  })
  
  # Sibilant plot
  
  output$plot1 <- renderPlot({
    sibilants %>% 
      #      filter(duration > input$range[1]) %>%
      #      filter(duration < input$range[2]) %>%
      ggplot(data = .,
             aes(x = phoneme, y = spectralcog)) +
      geom_violin(aes(fill = factor(phoneme)), width=0.5, trim=F) +
      geom_point()
  })
  
  # Cat image
  
  output$cat_image <- renderPlot({ 
    input$update
    isolate(meow::meow())
  })
  
  # These collect the click infos into tables
  
  output$click_info <- renderDataTable({
    nearPoints(sibilants, input$sibilant_click, addDist = FALSE)
  })
  
  output$vowel_click_info <- renderDataTable({
    nearPoints(vowels, input$vowel_click, addDist = FALSE)
  })
  
  # This may be worth testing: brush selects an area
  
  # output$brush_info <- renderText({
  #   #brushedPoints(values, input$plot1_brush)
  #   time <- nearPoints(values, input$plot1_click, addDist = FALSE) %>% .$start_time
  #   time
  # })
  # 
  
  # This ties opening the file into button
  observeEvent(input$action, {
    open_praat(filename = nearPoints(vowels, input$vowel_click, addDist = FALSE) %>% .$filename, start = 1, end = 2)
  })
  
  # Same, doesn't work now
  observeEvent(input$open_sibilant, {
    open_praat(filename = nearPoints(values, input$sibilant_click, addDist = FALSE) %>% .$filename, start = 1, end = 2)
  })
  
  # This plays sound, but doesn't work now, have to check why
  observeEvent(input$play, {
    current_selection <- nearPoints(vowels, input$vowel_click, addDist = FALSE) %>% slice(1) %>% .$filename
    
    phoneme_start <- nearPoints(values, input$vowel_click, addDist = FALSE) %>%
      slice(1) %>%
      mutate(time_start = as.numeric(time_start)) %>%
      .$time_start
    
    phoneme_end <- nearPoints(vowels, input$vowel_click, addDist = FALSE) %>%
      slice(1) %>%
      mutate(time_end = as.numeric(time_end)) %>%
      .$time_end
    
    current_full <-glue('{textgrids_and_wavs}/{current_selection}.wav')
    current_click <- tuneR::readWave(current_full)
    listen(current_click, from = phoneme_start - 0.2, to = phoneme_end + 0.2)
  })
  
})
