#!/usr/bin/env Rscript

# plot 1: Distance of features based on final hits
# plot 2: Genomic location of annotated peaks based on final hits
# plot 3 - only if more than one feature is present: Feature distribution across final hits
## following plots only if more than one query is defined
# plot 4: Distance of query vs. feature based on best per query hits
# plot 5: Genomic location of annotated peaks based on best per query hits
# plot 6 - only if more than one feature is present: Feature distribution across best per query hits
# plot 7: pairwise comparison of queries with regard to all peaks based on best per query hits
# plot 8 - only if three to five queries are defined: Chow-Ruskey diagram based on best per query hits
# used packages

suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(gridExtra))
# script gets arguments
args <- commandArgs(TRUE)
# basic information independent if there are 3 or 4 input arguments, used otherwhere as .basic.summary

num.features <- 0
features <- c()



# reformat every row of the config.query file to string for cover page
.print.query <- function(row){
	r <- paste(unname(as.vector(unlist(row))), collapse="   ")
	return(r)
}


# A helper function to define a region on the layout for the pie charts
.define_region <- function(f){
	if(f %% 2 != 0 ){
		grid.newpage()
		pushViewport(viewport(layout = grid.layout(2, 1)))
		viewport(layout.pos.row = 1, layout.pos.col = 1)
	} else {
		viewport(layout.pos.row = 2, layout.pos.col = 1)
	} 
} 
# helper for plot 2 and 5 (counts the occurence of each loci for pie charts)
.plot.genomic.location.per.feature.helper <- function(f, df.uropa, pie.basic){
	
	feat <- features[f]
	df.feature <- subset(df.uropa, df.uropa$feature==feat)
	unique.loci <- sort(unique(df.feature$genomic_location))

	occurence.loci <- c()
	for(j in 1:length(unique.loci)){
		loci <- as.character(unique.loci[j])
		occurence <- as.numeric(length(grep(loci, df.feature$genomic_location)))
		occurence.loci <- c(occurence.loci, occurence)
	}
	df.pie.full <- data.frame(location=unique.loci, value=occurence.loci)
	min.pie.chart.size <- round(nrow(df.feature)/100*0.1)
	df.pie <- df.pie.full[df.pie.full$value>min.pie.chart.size,]
	df.tmp <- df.pie.full[df.pie.full$value<=min.pie.chart.size,]
	df.others <- data.frame(location="others", value=sum(df.tmp$value))
	if(sum(df.tmp$value)>min.pie.chart.size){
		df.pie <- rbind(df.pie,df.others)
	}
	# calculate % oc loci representation
	perc <- round(df.pie$value/sum(df.pie$value)*100,1)
	df.pie$location <- paste0(df.pie$location, " (",perc, "%)")
	# now background
	blank_theme <- theme_minimal()+ theme(axis.title.x = element_blank(), axis.title.y = element_blank(), panel.border = element_blank(), panel.grid=element_blank(), axis.ticks = element_blank(), plot.title=element_text(size=14, face="bold"))
	# title
	main <- paste0("Genomic location of '",feat, "' across ",pie.basic)
	pie <- ggplot(df.pie, aes(x="", y=value, fill=location)) + geom_bar(width = 1, stat = "identity") + coord_polar("y", start=0) + blank_theme + theme(axis.text.x=element_blank()) + geom_text(aes(y = value/length(value) + c(0, cumsum(value)[-length(value)]),  label = rep("",nrow(df.pie))), size=2, nudge_x = 0.7, nudge_y = 0.7) + ggtitle(main) +  theme(plot.title = element_text(size = 10, face = "bold", , vjust=-10))	
	print(pie, vp=.define_region(f))
}

# plot 2 and plot 5
.plot.genomic.location.per.feature <- function(df.uropa,pie.basic){
	# layout of plot
	# if there is more than one feature, there should two columns and the according number of rows
	for(f in 1:num.features){
		.plot.genomic.location.per.feature.helper(f, df.uropa, pie.basic)			
	}
}
# plot 3 and 6
.plot.feature.distribution <- function(df.uropa, header){
	if(num.features>1){
		occurence.features <- c()
		for(f in 1:num.features){
			feat <- features[f]
			o <- nrow(subset(df.uropa, df.uropa$feature==feat))
			occurence.features <- c(occurence.features,o)
		}
		names(occurence.features) <- features	
		barplot(occurence.features, ylab="occurence",main=header)
	}
}



# load final hits file, create coverpage, and calculate basic plots
.basic.summary <- function(final.hits, conf, out){
	pdf(file=out)
	plot.new()
	df.uropa.final <- read.table(final.hits, header=TRUE, sep="\t",stringsAsFactors = FALSE)
	# number of peaks annoteted with uropa run
	num.peaks <- length(unique(df.uropa.final$peak_id))
	# stats is based on annoted peaks -> remove na rows
	df.uropa.final[,"distance"] <- as.numeric(df.uropa.final[,"distance"])
	df.uropa.final <- df.uropa.final[complete.cases(df.uropa.final),]
	anno.peaks <- nrow(df.uropa.final)
	# get infos from config for overview page
	config <- fromJSON(conf)
	config.query <- as.data.frame(config$queries)
	
	config.cols <- colnames(config.query)
	priority <- config$priority

	# queries of uropa annotation run
	queries <- sort.int(as.numeric(unique(df.uropa.final$query)))
	num.queries <- length(queries)
	queries <- sprintf("%02d", queries)

	features <<- as.character(unique(df.uropa.final$feature))
	num.features <<- length(features)
	if(grepl("T",priority) && num.queries>1){
		priority <- paste0(priority, "\nNote: No pairwise comparisons and Chow Ruskey plot (no overlaps)")
	}
	# add query to query data frame	
	config.query$query <- paste0("query",sprintf("%02d",0:(nrow(config.query)-1)))
	config.query <- config.query[,c("query", "feature", "distance", "feature.anchor","internals", "strand","direction","filter.attribute", "attribute.value","show.attributes")]
	# replaye "start,center,end" position by "any_pos" 
	config.query$feature.anchor <- sapply(config.query$feature.anchor, function(x) if(length(x)==3){return("any_pos")}else{return(x)})
	mtext("UROPA summary", side=3, line=0,outer=FALSE, cex=2)
	mtext(paste0("There were ", num.peaks, " peaks in the input bed file,\nUROPA annotated ", anno.peaks, " peaks\n"),side=3, line=-3,outer=FALSE, cex=.7)
	if(num.queries != nrow(config.query)){
		mtext(paste("Only queries", paste(queries, collapse=","), "are represented in the FinalHits", sep=" "), side=3, line=-5,outer=FALSE, cex=.7)	
	}
	g <- tableGrob(config.query, gpar.coretext = gpar(col = "black", cex = .5), gpar.coltext = gpar(col = "black", cex = .5, fontface = "bold"),show.rownames=FALSE)
	grid.draw(g)
	mtext(paste0("priority: ", priority), cex=.7,side=1, line=-2)
	input <- paste("Input:",unlist(config$bed),collapse=" ")
	anno <- paste("Anno:",unlist(config$gtf),collapse=" ")
	input.anno <- paste(input,anno,sep="\n")
	mtext(input.anno,cex=.6, side=1, line=0)


	# plot 1 
	y.lim <- round(median(df.uropa.final[,"distance"]) + (max(df.uropa.final[,"distance"])/15))
	if(y.lim > max(df.uropa.final[,"distance"]) || y.lim > 10000){
		if(median(df.uropa.final[,"distance"]) + 5000 > max(df.uropa.final[,"distance"])){
			y.lim <- median(df.uropa.final[,"distance"])
			} else {
				y.lim <- median(df.uropa.final[,"distance"]) + 5000
			}
		
	}
	
	density <- subset(df.uropa.final[,c("distance","feature")], (df.uropa.final[,"distance"]<y.lim))
	dpq <- qplot(distance,data=density, geom="density", color=feature, xlab = "Distance to feature", ylab = "Relative count")
	print(dpq + ggtitle("Distance to features across FinalHits"))
	# plot 2
	.plot.genomic.location.per.feature(df.uropa.final, "FinalHits")
	# plot 3
	if(num.features > 1){
		.plot.feature.distribution(df.uropa=df.uropa.final,header="Feature distribution across FinalHits")
	}
	
	return(df.uropa.final)
}

# arg 1 = Final Hits
# arg 2 = summery config
# arg 3 = output pdf
# arg 4 = Best perQuery Hits

if(length(args)==3){
	## basic summary -- only one query definded
	df.uropa.final <- .basic.summary(args[1],args[2], args[3])
	dev.off()
} else if(length(args)==4){
	suppressPackageStartupMessages(library(VennDiagram))
	suppressPackageStartupMessages(library(gplots))


	## increased summary -- there is more than one query definded
	df.uropa.final <- .basic.summary(args[1],args[2], args[3])
	df.uropa.best.per.query <- read.table(args[4], header=TRUE, sep="\t",stringsAsFactors = FALSE)
	num.peaks <- length(unique(df.uropa.final$peak_id))
	df.uropa.best.per.query[,"distance"] <- as.numeric(df.uropa.best.per.query[,"distance"])
	df.uropa.best.per.query <- df.uropa.best.per.query[complete.cases(df.uropa.best.per.query),]
	features <<- as.character(unique(df.uropa.best.per.query$feature))
	num.features <<- length(features)
	queries <- sort.int(as.numeric(unique(df.uropa.best.per.query$query)))
	queries <- sprintf("%02d", queries)
	num.queries <- length(queries)


	# plot 4
	# get max distance to calculate binwidth
	dist <-  df.uropa.best.per.query[,"distance"]
	median.uropa.best <- median(dist)
	max.uropa.best <- max(dist)
	considered.distance <- median.uropa.best + round(max.uropa.best/15)
	if(considered.distance > max.uropa.best || considered.distance>10000){
		if(median.uropa.best + 5000 > max.uropa.best){
			considered.distance <- median.uropa.best 
		} else {
			considered.distance <- median.uropa.best + 5000
		}
		
	} 
	df.distance.query <- subset(df.uropa.best.per.query[,c("feature","distance","query")], (df.uropa.best.per.query[,"distance"] < considered.distance))
	max.distance.query <- round(max(as.numeric(df.distance.query[,"distance"])))
	bin.width <- round(max.distance.query/20)
	dpq <- qplot(df.distance.query[,2],data =df.distance.query, facets=query~feature, geom="histogram", binwidth=bin.width, xlab = "Distance to feature", ylab = "Total count")
	print(dpq + ggtitle("Distance of query vs. feature across BestperQuery Hits"))


	# plot 5
	.plot.genomic.location.per.feature(df.uropa.best.per.query, "BestperQuery Hits")
	# plot 6
	if(num.features > 1){
		.plot.feature.distribution(df.uropa=df.uropa.best.per.query,header="Feature distribution across BestperQuery Hits")
	}
	# plot 7
	# get annotated peaks unique for each query
	peaks.per.query <- list()
	for(q in 1:num.queries){
		peaks.per.query[[q]] <- unique(df.uropa.best.per.query[as.numeric(df.uropa.best.per.query$query)==as.numeric(queries[q]),"peak_id"])
		names(peaks.per.query)[[q]] <-  paste0("query",queries[q])
	}
	# number of pairwise compares: (n-1)n/2 with n = # queries
	# iterater for pairwise compare
	tmp.num.query <- 1
	all.peaks <- unique(df.uropa.best.per.query$peak_id)
	for(q in 1:(num.queries-1)){
		initial.query <- peaks.per.query[[paste0("query",queries[q])]]
		if(tmp.num.query < num.queries){
			for(c in num.queries:tmp.num.query){ 
				if(queries[q] != queries[c]){
					compare.query <- peaks.per.query[[paste0("query",queries[c])]]
					venn.object <- venn(list(initial.query, compare.query))
	 				pushViewport(viewport(x=.5, y=0.5, width=.72, height=.72))
	 				grid.rect(gp=gpar(fill="white",lty = "blank"),width = unit(1, "npc"), height = unit(1, "npc"))
	 				anno.initial.query <- as.numeric(venn.object["01","num"])+ as.numeric(venn.object["11","num"])
	 				anno.compare.query <- as.numeric(venn.object["10","num"])+ as.numeric(venn.object["11","num"])
	 				matches <- as.numeric(venn.object["11","num"])
	 				#grid.rect(fill="white")
	 				if(anno.initial.query != matches && anno.compare.query != matches){
	 					dist <- 0.02
	 				} else if(anno.compare.query == matches || anno.initial.query ==matches){
	 					dist <- c(0.02, -0.02, -0.02)
	 				} 
	 				venn.plot <- draw.triple.venn(num.peaks, anno.initial.query, anno.compare.query, anno.initial.query, matches, anno.compare.query, matches, category =c("all",paste0("query",queries[q]),paste0("query",queries[c])), 
	 					lwd = 2, lty ="solid", col =  c("black", "red","blue"), fill = c("white","red","blue"), cex=1, cat.pos = c(0,0,0), cat.dist = dist, reverse = FALSE, 
	 					cat.cex =1, cat.default.pos= "outer", alpha =  c(0,.4,.4), euler.d=TRUE, scaled=TRUE)
	 				grid.draw(venn.plot)
	 				mtext(paste0("Pairwise compare of ", paste0("query",queries[q]), " and ", paste0("query",queries[c])), side=3, line=0,outer=FALSE, cex=1)
	 				popViewport()
				}	
			}
		}		
		tmp.num.query <- tmp.num.query+1
	}

	# plot 8
	# only up to five queries because of Vennerable package support
	if(num.queries>2 && num.queries<=5){
		suppressPackageStartupMessages(library(Vennerable))
		tryCatch({
			num <- venn(peaks.per.query)[,"num"]
			if(num[length(num)] == 0){
				num <- num+1
			}
			# compute distribution
			v <- Venn(SetNames=paste0("query",queries), Weight=num)
			cv <- compute.Venn(v, type="ChowRuskey", doWeights=TRUE)
	
			# change FaceText size and line thickness
			gp <- VennThemes(cv, colourAlgorithm = "signature")
			gp[["FaceText"]] <- lapply(gp[["FaceText"]],function(gps){gps$fontsize<-10;gps})
			gp[["Set"]] <- lapply(gp[["Set"]],function(gps){gps$lwd<-.8;gps})
	
			#change label positions
			SetLabels <- VennGetSetLabels(cv)		
			max.x <- max(VennGetUniverseRange(cv)[,"x"])
			max.y <- max(VennGetUniverseRange(cv)[,"y"])
			for(i in 1:nrow(SetLabels)){		
				SetLabels[i,"x"] <- max.x
				SetLabels[i,"hjust"] <- "right"
				if(i==1){
					SetLabels[i,"y"] <- max.y/2
				} else {
					SetLabels[i,"y"] <- as.numeric(SetLabels[i-1,"y"])-5
				}
			}
			cv <- VennSetSetLabels(cv,SetLabels)

			# change face label positions - not yet implemented in package			
			facelabel <- as.data.frame(VennGetFaceLabels(cv))
			face.labels <- nrow(facelabel)
			for(i in 1:(face.labels-2)){
				facelabel[i,"x"] <- 2*facelabel[i,"x"]
				facelabel[i,"y"] <- 2*facelabel[i,"y"]
			}
			cv <- VennSetFaceLabels(cv,facelabel)

			# draw plot
			pushViewport(viewport(x=.5, y=0.5, width=.8, height=.7))
			grid.rect(gp=gpar(fill="white",lty = "blank"),width = unit(1.5, "npc"), height = unit(1.5, "npc"))	
			venn.draw <- plot(cv, gp=gp)
			grid.draw(venn.draw)
			mtext("Chow Ruskey comparison of all peaks annotated with UROPA", side=3, line=0,outer=FALSE, cex=1)
		}, error = function(e){
			cat("\nChowRuskey plot was invalid\n")
			mtext("Venn comparison of all peaks annotated with UROPA", side=3, line=0,outer=FALSE, cex=1.5)
		})
	}
	dev.off()
} else {
	stop("Usage: Rscript summary.R FinalHits.txt summary_config.json summary.pdf BestperQuery_Hits.txt")
}
