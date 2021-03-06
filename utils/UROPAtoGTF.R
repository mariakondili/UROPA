## author afust
## script loads file or folder with information about a given feature (e.g. downloaded tfbs downloaded from ucsc table browser)
## and generates custom gtf file from it
## columns in gtf file to creat:
## chr | source | feature | start | end | score | strand | frame | attributes
## basic columns that need to be present in input file(s)
## chr | start | end 
## it does not matter if the column is called chr or chrom, start or chromStart etc., most cases are checked
## if an unvalid input format is given the user is informed and the script stops
## all columns with same column names as those from gtf file are kept and the rest is merged in attributes
## if there is a column without information, it is filled with dots
## column names of gtf file
c <- "chr"
so <- "source"
f <- "feature"
s <- "start"
e <- "end"
sc <- "score"
st <- "strand"
fr <- "frame"
a <- "attributes"
col.gtf <- c(c,so,f,s,e,sc,st,fr,a)
## if no info for a column is given, it will be filled with dots
dot <- "."

# combines additional given information to attribute column
# called for every single row
# column name (key) and entry (value) of current row are pasted, different information are sepreated by a semicolon
.attributes.combine <- function(row){
	additional.info <- ""
	for(row.position in 1:length(row)){
		key <- names(row[row.position])
		value <- as.character(row[key])
		# remove spaces
		if(grepl(" ",value)){
			value <- gsub("  ", " ", toString(value))
			value <- gsub("  ", " ", toString(value))
			if(substr(value,1,1) == " " ||  substr(value,length(value),length(value))){
				value <- gsub(" ", "", toString(value))
			} else {
				value <- gsub(" ", "_", toString(value))
			}
		}	
		if(value != "." && value !="" && !is.na(value)){
			current.info <- paste(as.character(key),value, sep=" ")	
			if(additional.info != ""){ 
				additional.info <- paste(additional.info, current.info, sep=" ; ")
			} else {
				additional.info <- current.info
			}
		} 
	} 
	if(additional.info == ""){
		additional.info <- paste("additional_info", ".", sep=" ")
	}
	return(additional.info)	
}



# reformat the input file to gtf file format 
.custom.gtf <- function(df.input, source, feature, threads){
	# chr, start, end have to be defined in the input file
	# source and feature can be given due to command line (if present in input, they will be overwritten)
	# also if there are columns, they will be overwritten
	# check for the other gtf columns if they are defined,
	# if yes, add them to the gft file, otherwise add dots in that line
	# order custom input
	df.input <- df.input[order(df.input$chr),]
	tryCatch({
	df.gtf <- df.input[, c(c,s,e)]
	df.input$chr <- NULL
	df.input$start <- NULL
	df.input$end <- NULL	
	
	cols <- colnames(df.input)
	# process optional parameter columns
	if(as.character(source)=="undefined" && any(grep(so, cols))){
		df.gtf$source <- df.input$source
		df.input$source <- NULL
	} else {
		df.gtf$source <- rep(source,nrow(df.gtf))
	}
	if(as.character(feature)=="undefined" && any(grep(f, cols))){
		df.gtf$feature <- df.input$feature
		df.input$feature <- NULL
	} else {
		df.gtf$feature <- rep(feature,nrow(df.gtf))
	}
	
	# if there are more columns, they will be checked for valid gtf cols, otherwise requiered cols will be filled with dots
	if(ncol(df.input)>0) { 
		cols <- colnames(df.input)
	# check if column exists in input
	# if yes, add to gtf file and remove from input data frame
	# if no, add dots for this column	
		if(any(grepl(sc,cols))){
			df.gtf$score <- df.input$score
			df.input$score <- NULL
		} else {
			df.gtf$score <- rep(dot, nrow(df.gtf))
		}
		if(any(grepl(st,cols))){
			df.gtf$strand <- df.input$strand
			df.input$strand <- NULL
		} else{
			df.gtf$strand <- rep(dot, nrow(df.gtf))
		}
		if(any(grepl(fr,cols))){
			df.gtf$frame <- df.input$frame
			df.input$frame <- NULL
		} else{
			df.gtf$frame <- rep(dot, nrow(df.gtf))
		}
		if(any(grepl(a,cols))){
			df.gtf$attributes <- df.input$attributes
			df.input$attributes <- NULL
		}
		## check if there are still further information, if yes combind them
		if(ncol(df.input)>0){
			# if multi threads are given, use them
			if(threads==1){
				attributes.combined <- apply(df.input, 1, .attributes.combine)
			} else {
				library(snow)
  				c <- makeSOCKcluster(rep("localhost",threads))
  				attributes.combined <- parRapply(c, df.input, .attributes.combine)
  				stopCluster(c)
			}
			# check if there is already an attribute column, if yes append combound attributes
			if(!any(grepl(a,colnames(df.gtf)))){
				df.gtf$attributes <- attributes.combined 
			} else {
				# if there is already a attribute column, add combound attributes to this column
				attributes.combined <- paste(df.gtf$attributes,attributes.combined, sep=" ; ")				
				df.gtf$attributes <- NULL
				df.gtf$attributes <- attributes.combined
			} 
		}
		# if there is no attribute column after all, add one
		if(!any(grepl(a,colnames(df.gtf)))){ 
			df.gtf$attributes <- paste("entry", 1:nrow(df.gtf), sep=" ")
		}


	} else {
		df.gtf$score <- rep(dot, nrow(df.gtf))
		df.gtf$strand <- rep(dot, nrow(df.gtf))
		df.gtf$frame <- rep(dot, nrow(df.gtf))
		df.gtf$attributes <- paste("entry", 1:nrow(df.gtf), sep=" ")
	}
	df.gtf <- df.gtf[,col.gtf]
	return(df.gtf)
	}, error = function(e){
		cat("\r\t\t File(s) with invalid input format will be ignored!")
	})
}

# adapts header by sub values often used from UCSC table browser to a valid format
.adapt.header <- function(df.modify){
	cols <- colnames(df.modify)
	cols <- unlist(lapply(cols, tolower))
  	cols <- sub("chromstart", "start", cols)
  	cols <- sub("chromend", "end", cols)
  	cols <- sub("chrom", "chr", cols)
  	cols <- sub("x.bin", "bin", cols)
  	colnames(df.modify) <- cols  	
  	if(!any(grepl("chr",cols)) && !any(grepl("start",cols)) && !any(grepl("end",cols))){
  			stop("\nIncorrect input format of", basename(files[1]),"\nFile should have a header with chr start end information.\n")
  	}
  	return(df.modify)
}


# reformat all files from input folder to gtf format
# every single file will be stored to the given output dir
# filenames should be the table names, or at least a clearly id which table it is, 
# because this will be added as table to the gtf file (attribute column)
.merge.files <- function(indir,outdir, source, feature, threads){
	# list all files from input folder
	files<-list.files(indir,include.dirs = FALSE)  
  	setwd(indir)
  	num.files <- length(files)
  	# Load and reformat first file
  	df.merged <- read.csv(files[1], header=TRUE, sep="\t")
  	df.merged <- .adapt.header(df.merged)
	
  	# add file name as column to data frame
 	current.table <- (strsplit(as.character(basename(files[1])),"[.]"))[[1]][1]
  	df.merged$table <- rep(current.table,nrow(df.merged))
  	current.table <- paste(current.table,"gtf",sep=".")
  	current.table <- paste(outdir,current.table,sep="")
  	
  	# remormatting 	
  	cat("\nto GTF",1, "/", num.files)
  	df.merged <- .custom.gtf(df.merged, source, feature, threads)  	
  	write.table(df.merged, file=current.table, append =FALSE, quote=FALSE,sep='\t', eol='\r\n',row.names = FALSE, col.names = FALSE)
  	# do the same for all table in input folder, plus merge them to existing data frame
  	count <- 2
  	for (file in files[2:num.files]){  
  		current.table <- (strsplit(as.character(basename(file)),"[.]"))[[1]][1]
  		cat("\rto GTF",count, "/", num.files)
  		df.tmp <- read.csv(file, header=TRUE,sep="\t")
  		df.tmp <- .adapt.header(df.tmp)  
    	
    	df.tmp$table <- current.table   	
    	df.tmp <- .custom.gtf(df.tmp,source, feature, threads)
    	current.table <- paste(current.table,"gtf",sep=".")
    	current.table <- paste(outdir,current.table,sep="")
    	write.table(df.tmp, file=current.table, append =FALSE, quote=FALSE,sep='\t', eol='\r\n',row.names = FALSE, col.names = FALSE)
    	df.merged <- rbind(df.merged, df.tmp)
    	count <- count+1
	}
	return(df.merged)
}


## Script gets arguments
args <- commandArgs(TRUE)
#positional argument
# $1 = file or folder with input table(s) which should be reformatted to gtf file format
# optional arguments, order does not matter, varyfied by argument=value pattern
# $2 = source
# $3 = feature
# $4 = threads
num.args <- length(unlist(args))
if(num.args >= 1 && num.args <= 4){
	cat("Preprocessing..")
	# process input
	input <- args[1]
	if(num.args > 1 && !any(grepl("source",args)) && !any(grepl("feature",args)) && !any(grepl("threads",args))){
		stop("Invalid optional argument, use optional arguments with source=yourSource feature=yourFeature threads=#threads")
	}
  	# check if optional inputs are given and validate them
  	if(any(grep("source",args))){
  		source <- grep("source",args, value=TRUE)
  		source <- unlist(strsplit(source, "="))[2]
	} else {
		source <- "undefined"
	}
	if(any(grep("feature",args))){
  		feature <- grep("feature",args, value=TRUE)
  		feature <- unlist(strsplit(feature, "="))[2]
	} else {
		feature <- "undefined"
	}
	if(any(grep("threads",args))){
  		threads <- grep("threads",args, value=TRUE)
  		threads <- as.numeric(unlist(strsplit(threads, "="))[2])
	} else {
		threads <- 1
	}
	cat("done.\n")

  	# distinguish between input file and dir
  	if(file_test("-f",input)){
  		cat("Input is a file: To GTF..")
  		df.input <- read.csv(input, header=TRUE, sep="\t")
  		df.input <- .adapt.header(df.input)
		# create output file name
		# set outdir to to full path
  		outdir <- dirname(normalizePath(input))
  		outdir <- paste(outdir, "/", sep="")
  		current.table <- (strsplit(as.character(basename(input)),"[.]"))[[1]]
  		current.table <- current.table[1:(length(current.table)-1)]
  		if(length(current.table)>1){
  			current.table <-paste(current.table, collapse=".")
  		} 	
  		current.table <- paste(current.table,"gtf",sep=".")
  		output <- as.character(paste(outdir,current.table,sep=""))
  		df.gtf <- .custom.gtf(df.input, source, feature, threads)
  		write.table(df.gtf, file=output, append =FALSE, quote=FALSE,sep='\t', eol='\r\n',row.names = FALSE, col.names = FALSE)
  		cat("done.\n")
  	}  else if(file_test("-d",input)){
  		outdir <- paste(dirname(normalizePath(input)), basename(input), sep="/")
  		outdir <- paste0(outdir,"/")
  		cat("Input is a dir: Reformat to gtf file format and merge ..")
  		df.merged <- .merge.files(input,outdir, source, feature, threads)
  		output <- paste(outdir,"UROPAtoGTF_merged.gtf", sep="")
  		write.table(df.merged, file=output, append =FALSE, quote=FALSE,sep='\t', eol='\r\n',row.names = FALSE, col.names = FALSE)
  		cat("\ndone.\n")
  	}
} else{
	# error message displayed if script is not called as it should be called
	cat("ERROR:	Wrong use of custom gtf file generation script, use script like this: 

	Rscript UROPAtoGTF.R <input> source=yourSource feature=yourFeature threads=#threads

	--> source, feature, and threads are optional: depending from input, e.g. source=UCSC
	<input> can be a file or a folder (transform one file / transform and merge many files)
	output files will be stored in same direction as input.
	Notes: 	Make sure input file(s) contain header with information about chr, start, and end
			Make sure file names do not contain any dots
			Make sure there are no other files in the input folder but those to merge!!
			If threads should be used, the package 'snow' is requiered
	\r\n")
}