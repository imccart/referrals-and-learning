# Meta --------------------------------------------------------------------
## Title:         Physician Shared Patients Data with Duntsch (1790916393)
## Author:        Ian McCarthy
## Date Created:  10/21/2021
## Date Edited:   10/21/2021


# Preliminaries -----------------------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, ggplot2, dplyr, lubridate, stringr,
               igraph, network, sna, ggraph, visNetwork, threejs,
               networkD3, ndtv)



# PSPD Data ---------------------------------------------------------------

for (t in 2009:2015) {
  PSPD.full <- read_csv(paste0("data/Physician Shared Patients 180-days/PSPD ",t,".txt"), 
                        col_names=c("npi1","npi2","paircount","benecount","samedayvisits"), 
                        col_types = cols(
                          npi1=col_character(),
                          npi2=col_character(),
                          paircount=col_double(),
                          benecount=col_double(),
                          samedayvisits=col_double() 
                        ))

  duntsch.dat <- PSPD.full %>%
    filter(npi1==1790916393 | npi2==1790916393)
  
  if (t==2009) {
    duntsch.full <- duntsch.dat
  } else {
    duntsch.full <- bind_rows(duntsch.full, duntsch.dat)
  }
}
saveRDS(duntsch.full, file="data/duntsch-data.RData")
rm("PSPD.full")


# Merge Taxonomy Data -----------------------------------------------------
duntsch.dat <- readRDS("data/duntsch-data.RData")

taxonomy <- read_csv("data/npi_wdata.csv", 
                     col_types = cols(
                       npi=col_character(),
                       zip=col_character(),
                       state=col_character(),
                       t_code=col_character(),
                       desc_tax=col_character()
                     ))

duntsch.tax <- duntsch.full %>%
  left_join(taxonomy, by=c("npi1"="npi")) %>%
  rename(zip1=zip, state1=state, t_code1=t_code, desc_tax1=desc_tax)



# View Network ------------------------------------------------------------


