# START code from parse_mplus_template.R
# Note: You may change the code in parse_mplus_template.R to change it for
#       all future files.

# Make a new R graphics window of 10x6cm. Do not use R Studio's (if available).
# Note that currently saving from this window will not set the DPI correctly, hence why
# we have tiff(...) and png(...) code commented out below.
dev.new(width=10,height=6,res=1200,units="cm",noRStudioGD = TRUE)

# Output image file of 10x6cm with resolution 1200 dpi (seems to be capped at 472dpi)
#tiff( paste(output_filename, '.tif', sep=""), width=10,height=6,res=1200,units="cm",pointsize=5)
#png( paste(output_filename, '.png', sep=""), width=10,height=6,res=1200,units="cm",pointsize=5)

# Set below to FALSE to do 1 plot per class (default is 1 combined plot)
do_combined_plot=TRUE
if ( do_combined_plot ) {
  # Do just one combined plot for all classes (default)
  
  # mfrow=c(1,1) == 1 rows, 1 columns of plots
  # Ex: mfrow=c(3,2) == 3 rows, 2 columns of plots
  # mar - A numerical vector of the form c(bottom, left, top, right) which gives 
  #       the number of lines of margin to be specified on the four sides of the plot.
  #       The default if not given is c(5, 4, 4, 2) + 0.1.
  # This custom code for mar= tries to automatically adjust the margin
  # depending on the longest variable name in varlab, along with giving enough space for
  # axis labels and the default top legend.
  par(mfrow=c(1,1),mar=c(max(6.5,max(nchar(varlab))/1.3 + 0.1), 4, 3, 0.5) + 0.1)
  
  # NOTE: To remove the label at the top, change to "plot(...,main="")" keeping the rest the same. (Default is "5C June10mp boys n girls MORE.out" so you know which file this figure came from)
  # main="" - label at top (default: blank)
  # ylim=c(0,1) - limit for y-axis (default: 0-1.0)
  # ylab=ylabel - label for y-axis (default: ylabel, defined above)
  # xlab=xlabel - label for x-axis (default: xlabel, defined above)
  # cex.axis=0.75 - Percentage size of font for variable names on x axis
  # font.lab=2 - Bold the axis labels
  # line=... - The call to title() uses a bit of code to try and automatically position 
  #            the x axis label based on longest length of variable names
  plot(0,0,ylim=c(0,1),xlim=c(1,nvar),col=0,ylab=ylabel,font.lab=2,xaxt="n",xlab="",main="",cex.axis=0.8)
  axis(1,at=seq(1:nvar),labels=varlab,las=2,cex.axis=0.75,xlab="",xlim=c(1,nvar))
  title(xlab=xlabel, line=max(4,max(nchar(varlab))/1.5),font.lab=2)
  
  # PARAMETERS FOR EACH PLOTTED LINE AND POINTS
  # Iterate over each class, adding the lines and points to the plot for each CI matrix
  # lty -- line types: "blank", "solid", "dashed", "dotted", "dotdash", "longdash", "twodash"
  # col -- colour (default: per class)
  # pch -- point symbol type (default: per class)
  # cex -- size of point symbols (default: 0.4)
  # lwd -- line width (default: not used)
  for(j in 1:nclass){
    # Solid CI Est + Dotted CI Bands
    lines(x=rep(1:nvar),y=ciestimates_matrix[,j],lty="solid",col=colors[j])
    lines(x=rep(1:nvar),y=cilower2p5_matrix[,j],lty="dotted",col=colors[j])
    lines(x=rep(1:nvar),y=ciupper2p5_matrix[,j],lty="dotted",col=colors[j])
    points(x=rep(1:nvar),y=ciestimates_matrix[,j],col=colors[j],pch=j,cex=0.4)
    points(x=rep(1:nvar),y=cilower2p5_matrix[,j],col=colors[j],pch=j,cex=0.4)
    points(x=rep(1:nvar),y=ciupper2p5_matrix[,j],col=colors[j],pch=j,cex=0.4)
  } # end for
  
  # SET LEGEND - comment out "legend(...)" to disable legend
  # legend.text - The actual legend text, defined earlier
  # bty="n" - no border or background
  # text.font=2 - bold
  # col - colors (default: per class)
  # ncol - number of columns for legend (default: 4)
  # pch - point symbols (default: per class)
  # xpd = T - Allow drawing legend outside of the plotting area.
  #
  # You may use positions such as "topright" for the legend,
  # but here we use x and y positioning along with "xpd = T" to
  # position the legend outside of the plotting area (relative to axis scale).
  
  # Legend above plot in 4 columns
  legend(x=0, y=1.2, legend.text,text.font=2,bty="n",pch=rep(1:nclass), col=colors, ncol=4, xpd = T)
  
  # Legend to the top-right in 3 columns
  #legend(x=nvar/2,y=1.05, legend.text,text.font=2,bty="n",pch=rep(1:nclass), col=colors, ncol=3, xpd = T)
  
} else {
  # Make a plot for each class
  
  # mfrow - A vector of the form c(nr, nc). Subsequent figures will be drawn in an nr-by-nc 
  #         array on the device by columns (mfcol), or rows (mfrow), respectively.
  # mar - A numerical vector of the form c(bottom, left, top, right) 
  #       which gives the number of lines of margin to be specified on the four sides of the
  #       plot. The default if not given is c(5, 4, 4, 2) + 0.1.
  # Ex: mfrow=c(3,2) == 3 rows, 2 columns of plots
  # This custom code for mar= tries to automatically adjust the margin
  # depending on the longest variable name in varlab, along with giving enough space for
  # axis labels.
  par(mfrow=c(3,ceiling(nclass/3)), mar=c(max(6.5,max(nchar(varlab))/1.3 + 0.1), 4, 3, 0.5) + 0.1)
  
  # Iterate over each class, making both the plot and lines for each matrix
  for(j in 1:nclass) {
    # main=legend.text[j] - label at top of plot (we use classnames here, defined earlier)
    # ylim=c(0,1) - limit for y-axis (default: 0-1.0)
    # ylab=ylabel - label for y-axis (default: ylabel, defined above)
    # xlab=xlabel - label for x-axis (default: xlabel, defined above)
    # cex.axis=0.75 - Percentage size of font for variable names on x axis
    # font.lab=2 - Bold the axis labels
    # line=... - The call to title() uses a bit of code to try and automatically position 
    #            the x axis label based on longest length of variable names
    plot(0,0,ylim=c(0,1),xlim=c(1,nvar),col=0,ylab=ylabel,font.lab=2,xaxt="n",xlab="",main=legend.text[j])
    axis(1,at=seq(1:nvar),labels=varlab,las=2,cex.axis=0.75,xlab="",xlim=c(1,nvar))
    title(xlab=xlabel, line=max(4,max(nchar(varlab))/1.5),font.lab=2)
    
    # lty -- line types: "blank", "solid", "dashed", "dotted", "dotdash", "longdash", "twodash"
    # col -- colour (default: per class)
    # pch -- point symbol type (default: per class)
    # cex -- size of point symbols (default: 0.4)
    # lwd -- line width (default: not used)
    lines(x=rep(1:nvar),y=ciestimates_matrix[,j],lty="solid",col=colors[j])
    lines(x=rep(1:nvar),y=cilower2p5_matrix[,j],lty="dotted",col=colors[j])
    lines(x=rep(1:nvar),y=ciupper2p5_matrix[,j],lty="dotted",col=colors[j])
    points(x=rep(1:nvar),y=ciestimates_matrix[,j],col=colors[j],pch=j,cex=0.4)
    points(x=rep(1:nvar),y=cilower2p5_matrix[,j],col=colors[j],pch=j,cex=0.4)
    points(x=rep(1:nvar),y=ciupper2p5_matrix[,j],col=colors[j],pch=j,cex=0.4)
  } # end for
  
} # end if do_combined_plot

# END code from parse_mplus_template.R