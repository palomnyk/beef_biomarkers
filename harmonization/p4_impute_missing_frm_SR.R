#Author: Aaron Yerke (aaronyerke@gmail.com)
#Script for imputing missing nutrition data from SR data

# TODO weight first word as highest - Split both at comma's
# Calculate absolute best score and then set threshold for our max score
# Incorporate length and position
# Record top 3 matches so we can check by hand
# Bias towards simplest SR code description
# Incorporate "skip" words - also only use words that are 3 char or more
"
New plan for scoring:
Score is square of nchar
Divide score by index of the word.
Drop all 1-2 letter words.
Add BF for any with BEEF as a word.
Add BNS for any ESHA with BEANS
Record top 3 matches.
"
# Sometimes SR uses bf as shorthand for beef - also has beef

rm(list = ls()) #clear workspace

#### Loading libraries and data ####
#read in libraries
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
if (!requireNamespace("ggplot2", quietly = TRUE))  BiocManager::install("ggplot2")
library("ggplot2")
if (!requireNamespace("openxlsx", quietly = TRUE))  BiocManager::install("openxlsx")
library("openxlsx")
if (!requireNamespace("data.table", quietly = TRUE))  BiocManager::install("data.table")
library("data.table")
print("Libraries are loaded.")

#Read in data
data_dir <- file.path("nutrition_data")

esha_studies_leo <- openxlsx::read.xlsx(xlsxFile = file.path(data_dir, "esha_combined_meats_HEI_vals28Sep2023.xlsx"),
                                     sheet = 1)
#esha_studies_leo combines the micro-nutrient esha output from MAP/MED studies

dietary_data <- openxlsx::read.xlsx(xlsxFile = file.path(data_dir, "HEI_with_proportions_long.xlsx"),
                                           sheet = 1)
#dietary_data contains the HEI and meat labels for each food in esha_studies_leo

sr_table <- openxlsx::read.xlsx(xlsxFile = file.path(data_dir, "NUT_DATA_Crosstab.xlsx"))
#SR table from which we will try to fill in missing values for esha_studies_leo

sr_header_def <- openxlsx::read.xlsx(xlsxFile = file.path(data_dir, "NUTR_DEF.xlsx"))
#headers for sr_table

words_to_omit_from_search <- c("with", "and", "a", "to")
#to be used for label processing

SR_abrev_words <- c("RAW")

#### Add labels to "sr_table" from definitions table ####
sr_header_def$Nutr_No <- as.character(sr_header_def$Nutr_No)#same mode as sr_table

old_cols <- colnames(sr_table)[3:ncol(sr_table)]#Columns to look up

sr_cols <- lapply(old_cols, function(x){
  return(sr_header_def[which(sr_header_def$Nutr_No == x), "NutrDesc"])
})#returns new column names 

sr_cols <- c(colnames(sr_table)[1:2], unlist(sr_cols))

colnames(sr_table) <- sr_cols

#### Find matches between dietary items and sr short descriptions ####
best_matches <- data.frame(#"esha_dscr" = vector(mode = "character", length = nrow(dietary_data)),
                           "sr_dscr" = vector(mode = "character", length = 0),
                           "num_same_score" = vector(mode = "integer", length = 0),
                           "match_score" = vector(mode = "integer", length = 0))

"
Cycle through each food in the dietary data,
Convert it to upper, remove punctuation,
Split it at punctuation,

Cycle through each item in SR table,

"
for (itm2 in 1:nrow(dietary_data)) {
  my_item <- toupper( dietary_data$item[itm2])
  itm_no_punct <- gsub('[[:punct:] ]+',' ', my_item)
  my_words <- unique(unlist(strsplit(itm_no_punct, " ")))
  #some words are abreviated by SR, adding abrebiations of important words
  dietary_scores <- vector(mode = "integer", length = nrow(sr_table))
  names(dietary_scores) <- sr_table$Shrt_Desc
  best_possible_score <- sum(unlist(lapply(my_words, function(x) nchar(x)^2)))
  for (itm1 in 1:length(dietary_scores)) {
    desc <- names(dietary_scores)[itm1]
    desc_no_punct <- gsub('[[:punct:] ]+','', desc)
    score <- 0
    for (word in my_words){
      if ( grepl(word, desc_no_punct, fixed = TRUE)){
        # print(score)
        score <- score +  nchar(word)^2
      }
    }# End for word
    dietary_scores[itm1] <- score
  }# End for itm1
  max_score <- max(dietary_scores)[1]
  # print(length(max(dietary_scores)))
  # if (max_score > best_possible_score/length(my_words)){
    # print(length(which(dietary_scores == max_score)))
    # print(which(dietary_scores == max_score))
    best_match <- names(dietary_scores)[which(dietary_scores == max_score)][1]
    best_matches[my_item,] <- c(best_match, 
                                length(which(dietary_scores == max_score)),
                                max_score[1])
  # }
}# End for itm2

write.csv(best_matches, file = file.path("nutrition_data", ""))