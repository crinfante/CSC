### -----------------------------------------------------------------
### read the bed file into GRanges.
###
readBedR = function(bedFile){
## This GRanges is in 1-based.
  bed = import.bed(bedFile, asRangedData = FALSE)
  strand(bed) = "+"
  bed = reduce(bed)
}

### -----------------------------------------------------------------
### read the bed file (with only 3 columns) into GRanges.
###
readBed = function(bedFile=NULL){
## This GRanges have the different coordinates system 
## with the original bed file. i.e. with 1-based start end coordinates.
  if(is.null(bedFile)){
    return(NULL)
  }
  if(!file.exists(bedFile)){
    stop("No such file ", bedFile) 
  }
  bed = .Call2("myReadBed", bedFile, PACKAGE="CNEr")
  bed = GRanges(seqnames=Rle(bed[[1]]),
                ranges=IRanges(start=bed[[2]], end=bed[[3]]),
                strand=factor("+"))
  return(bed)
}

### -----------------------------------------------------------------
### read the axt files into an axt object.
###
readAxt = function(axtFiles){
  # Read axt files into R axt object.
  # The coordinates are 1-based for start and end.
  index_noexists = !file.exists(axtFiles)
  if(any(index_noexists)){
    stop("No such file ", paste(axtFiles[index_noexists], sep=" "))
  }
  myAxt = .Call2("readAxt", axtFiles, PACKAGE="CNEr")
  axts = axt(targetRanges=GRanges(seqnames=Rle(myAxt[[1]]),
                                 ranges=IRanges(start=myAxt[[2]],
                                                end=myAxt[[3]]),
                                 strand=Rle(myAxt[[4]])),
            targetSeqs=DNAStringSet(myAxt[[5]]),
            queryRanges=GRanges(seqnames=Rle(myAxt[[6]]),
                                ranges=IRanges(start=myAxt[[7]],
                                               end=myAxt[[8]]),
                                strand=Rle(myAxt[[9]])),
            querySeqs=DNAStringSet(myAxt[[10]]),
            score=myAxt[[11]],
            symCount=myAxt[[12]]
            )
  return(axts)
}

### -----------------------------------------------------------------
### read the axt files and return the widths of all the alignments
###
axtInfo = function(axtFiles){
  ans = .Call2("axt_info", axtFiles, PACKAGE="CNEr")
  return(ans)
}

