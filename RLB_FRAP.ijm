// RLB FRAP
// Done by RLB @ Imagerie-Gif 
// romain.lebars@i2bc.paris-saclay.fr
// Acknowledgements : Christophe Klein (christophe.klein@crc.jussieu.fr), Sylvain Jeannin


// Default variables
	// Bleachnig event (frame)
	BE = 6;
	// Diameter of the FRAP ROI (pixels)
	FD = 11;
	// Location of the FRAP Region
	BRx = 300;
	BRy = 300;
// Hidden options
	// Ask for registration ? (1=Yes ;  0=No)
	AskReg = 0;
	// Activate the live replay mode ?  (1=Yes ;  0=No)
	Live = 1;
	// Force a BG value (-1 = ignored, other = new BG value for all images)
	BG_Value =-1;
	// Correction of the acquisitional bleaching (1=Yes ; 0=No)
	Corr_Bleach = 1;
	// Activate the manual tracking of the bleached region (1=Yes ; 0=No)
	Manual= 0;

	run("Close All");


// FRAP Region
	if (Manual==0)
		{
		Dialog.create("FRAP ROI Properties");
		Dialog.addRadioButtonGroup("Do you know the size and location of the bleaching region ?", newArray("Yes", "No"),1 , 2, "No");
		Dialog.show;
		Know = Dialog.getRadioButton();
		}
	else
		{
		Know="Yes";
		}

	if (Know=="Yes")
		{
		Dialog.create("FRAP ROI Properties");
		Dialog.addMessage("Please specify the size and location of the bleached region (in pixel)");
		Dialog.addNumber("FRAP ROI height", FD);
		Dialog.addNumber("FRAP ROI width", FD);
		if (Manual==0){Dialog.addNumber("FRAP ROI Postion x", BRx);}
		if (Manual==0){Dialog.addNumber("FRAP ROI Postion y", BRy);}
		Dialog.addChoice("FRAP ROI Type" , newArray("oval", "rectangle"));
		//Dialog.addMessage("Analysis");
		//Dialog.addChoice("Fitting method" , newArray("Single exponential", "Double exponential"));
		Dialog.show;
		}

	if (Know=="Yes")
		{
		BRh = Dialog.getNumber();
		BRw = Dialog.getNumber();
		if (Manual==0){BRx = Dialog.getNumber();}
		if (Manual==0){BRy = Dialog.getNumber();}
		BRt = Dialog.getChoice();
		//FitMeth = Dialog.getChoice();	
		}

// Open an image with an .nd file and extract each real deltaT
	run("Bio-Formats Macro Extensions");
	id = File.openDialog("Choose a nd file");
	run("Bio-Formats Windowless Importer", "open="+"["+id+"]");
	path = File.directory;
	name = File.nameWithoutExtension;
	OriImg = getTitle();
	Ext.setId(id);
	Ext.getImageCount(imageCount);
	deltaT = newArray(imageCount);
	
	for (no=0; no<imageCount; no++){Ext.getPlaneTimingDeltaT(deltaT[no], no);}


// Clean Start
	run("Set Measurements...", "mean redirect=None decimal=2");
	roiManager("reset");
	run("Select None");
	print("\\Clear");
	run("Clear Results");
	roiManager("Show None");


// Information collection
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	Stack.getUnits(XUnit, YUnit, ZUnit, TimeUnit, Value);
	
	run("Enhance Contrast", "saturated=0.35");
	run("Fire");


// Deal with multiple channels

	if (channels > 2) {exit("This macro works only for 1 or 2 channels ... Sorry ...");}
	if (channels > 1)
		{
		run("Split Channels");
		run("Tile");
		// Select the channel to keep
		Dialog.create("Channel Selection");
		Dialog.addSlider("Select the channel to process.", 1, nImages, 1);
		Dialog.show();
		SelectedChannel = Dialog.getNumber();
		ChName = "Ch_"+SelectedChannel;
		selectImage(SelectedChannel);
		OriImg = getTitle();
		close("\\Others");	
	
	
		// Extraction of the individual timetable depending of the selected channel.
	
		for (a = SelectedChannel-1 ; a < frames ; a++)
			{
			deltaT = Array.deleteIndex(deltaT, a+1);
			}
		if (SelectedChannel == 2) {deltaT = Array.deleteIndex(deltaT, 0);}
		}


// Correct wrong image properties (z-stack instead of a t-stack)
	if (frames==1)
		{
		//frames=slices;
		run("Properties...", "slices=frames frames=slices ");
		getDimensions(width, height, channels, slices, frames);
		}


// Live Replay Mode
	if (Live == 1)
		{
		// Identify the BLeachnig Event ( Begin + End)
		Stack.setFrame(BE);
		waitForUser("Identify the first bleaching event frame ", "Live replay step 1 :  Set the first frame with the bleach event visible, and press 'OK!'" );
		Stack.getPosition(channel, slice, BBE);
		
		Stack.setFrame(BBE);
		waitForUser("Identify the post bleaching event", "Live replay step 2 : Set the first frame after the bleach event, and press 'OK!'" );
		Stack.getPosition(channel, slice, BE);
				
		// Identify the Bleaching Region (FRAP)
		if (Know=="No")
			{
			waitForUser("Bleaching Region", "Draw a region of interest around the bleached region. \n Press OK when done.");
			}
		else 
			{
			run("Specify...", "width="+BRw+" height="+BRh+" x="+BRx+" y="+BRy+" slice=&BE "+BRt+" centered");
			roiManager("Add");
			waitForUser("FRAP ROI", "If needed adjust the position of the ROI on the bleached region");
			}
			
		// Draw the FRAP region and update the variables
		setTool("oval");
		roiManager("reset");
		roiManager("Add");
		roiManager("Select", 0);
		roiManager("Rename", "FRAP");
		getSelectionBounds(BRx, BRy, BRw, BRh);
		BRt = Roi.getType;
		
		// Replace the frames with the bleaching occuring by the first frame before bleach
		Stack.setFrame(BBE-1);	
		run("Select None");
		run("Copy");
		for (b = BBE; b < BE; b++)
			{
			Stack.setFrame(b);
			run("Paste");
			}
		}			

// If requested, perform a Registration
	if (AskReg == 1)
		{
		waitForUser("Check if you need registration", "Check if you need to perform a registration of the stack ? \n	Make sure the bleached area does not drift along the timelapse.\n	If the drift is important concider applying a registration. \n \n	Press 'OK' when the check is over.");
		Dialog.create("Perform Stack Registration ?");
		Dialog.addRadioButtonGroup("Do you need to perform a stack registration ?", newArray("Register the stack !", "Leave as is."),1 , 2, "Register the stack !");
		Dialog.show;
		Reg = Dialog.getRadioButton();
	
		if(Reg=="Register the stack !")
			{
				setTool("rectangle");
				waitForUser("Registration ROI", "Draw a region around your object of interest or nothing compute a global drift correction");
				Mode = getValue("Mode");
				run("Correct 3D drift", "channel=1 correct multi_time_scale sub_pixel edge_enhance only=Mode lowest=1 highest=1 max_shift_x=10.000000000 max_shift_y=10.000000000 max_shift_z=10");
				close(OriImg);
				selectWindow("registered time points");
				rename(OriImg);
				run("Enhance Contrast", "saturated=0.35");
				run("Fire");
				print("\\Clear");
			}
		}


// MDA FRAP File	
	if (Live == 0) 
		{
		// Identify the Bleaching Event (frame)	
		Stack.setFrame(BE);
		waitForUser("Identify the bleaching event", "Set the first frame after the bleach event, and press 'OK!'" );
		Stack.getPosition(channel, slice, BE);
		
		// Identify the Bleaching Region (FRAP)
		if (Know=="No")
			{
			setTool("oval");
			waitForUser("Bleaching Region", "Draw a region of interest around the bleached region. \n Press OK when done.");
			}
		else if (Manual == 0)
			{
			run("Specify...", "width="+BRw+" height="+BRh+" x="+BRx+" y="+BRy+" slice=&BE "+BRt+" centered");
			roiManager("Add");
			waitForUser("FRAP ROI", "If needed adjust the position of the ROI on the bleached region");
			}
		else if (Manual == 1)
			{
			run("Specify...", "width=120 height=20 x=70 y=80 centered");
			}
		
		
		// Draw the FRAP region and update the variables
		roiManager("reset");
		roiManager("Add");
		roiManager("Select", 0);
		if (Manual==0) 
			{
			roiManager("Rename", "FRAP");
			getSelectionBounds(BRx, BRy, BRw, BRh);
			BRt = Roi.getType;
			}
		else {roiManager("Rename", "Manual FRAP");}
		}

// Print the properties of the FRAP region
	print("First post-bleaching frame : "+BE);
	print("");
	print("Bleaching region properties :");
	print("   Width : "+BRw+" (pixel)");
	print("   Height : "+BRh+" (pixel)");
	if (Manual==0)
		{
		print("   Position(x) : "+BRx+(BRw/2)+" (center in pixel)");
		print("   Position(y) : "+BRy+(BRh/2)+" (center in pixel)");
		}
	else {print("   Manual tracking of the bleached region");}
	print("   Region type : "+BRt);
	print("");
	if (Corr_Bleach==0){print("Acquisition bleaching correction : disabled.");}
	else {print("Acquisition bleaching correction : ROI.");}
	if (BG_Value==-1){print("Background subtraction : ROI");}
	else {print("Background subtraction : "+BG_Value+" (fixed value).");}
	print("");
	print("-------------------------ANALYSIS---------------------");


// Quantify the acquisitional bleaching (Ref_Cell)
	if (Corr_Bleach==1)
		{
		setTool("polygon");
		run("Select None");
		ValCell = 0;

		while (ValCell == 0)
			{
			waitForUser("Acquisitional Bleaching Correction", "Draw a selection around a fluorescent object  \n to estimate the acquisitional bleaching and correct it. \n \n Press OK when ready !");
			run("Plot Z-axis Profile");
			rename("Zprofile");
			ValCell = getBoolean("Is the Acquisitional Bleaching region OK ?","Yes !","No, let's do it again.");
			selectWindow("Zprofile");
			close();
			}
		roiManager("Add");
		roiManager("Select", 1);
		roiManager("Rename", "Ref_Cell");
		}
	else 
		{
		run("Specify...", "width=120 height=20 x=70 y=20 centered");
		roiManager("Add");
		roiManager("Select", 1);
		roiManager("Rename", "No_Bleach_Corr");
		}
	run("Select None");
	
// Select the Background Region (BG)
	if (BG_Value==-1)
		{
		setTool("polygon");
		ValBG = 0;
		selectWindow(OriImg);
		run("Select None");

		while (ValBG == 0)
			{
			waitForUser("Background Subtraction", "Draw a selection around an empty field of your image \n to use it for background subtraction. \n \n Press OK when ready !");
			run("Plot Z-axis Profile");
			rename("Zprofile");
			ValBG = getBoolean("Is the background region OK ?","Yes !","No, let's do it again.");
			selectWindow("Zprofile");
			close();
			}
		roiManager("Add");
		roiManager("Select", 2);
		roiManager("Rename", "BG");
		}
	else 
		{
		run("Specify...", "width=120 height=20 x=70 y=50 centered");
		roiManager("Add");
		roiManager("Select", 2);
		roiManager("Rename", "Fixed_BG");
		}
	run("Select None");

	//Save the ROIs & Map
	roiManager("Deselect");
	if (channels > 1){roiManager("Save", path+File.separator+name+"_"+ChName+"_RoiSet.zip");}
	else{roiManager("Save", path+File.separator+name+"_RoiSet.zip");}
	selectWindow(OriImg);
	Stack.setFrame(BE);
	run("Duplicate...", "title=Map ignore");
	roiManager("Deselect");
	run("Select None");
	run("From ROI Manager");
	Overlay.setLabelFontSize(18);
	roiManager("UseNames", "true");
	roiManager("Show All with labels");	
	if (channels > 1){saveAs("PNG", path+File.separator+name+"_"+ChName+"_FRAP_Map");}
	else {saveAs("PNG", path+File.separator+name+"_FRAP_Map");}
	close();

// Array creation to perform corrections
	time=newArray(frames);
	frap=newArray(frames);
	bleach=newArray(frames);
	backgrd=newArray(frames);
	frap_corr=newArray(frames);
	frap_corr_norm=newArray(frames);
	frap_corr_2xnorm=newArray(frames);

// Measurments
	roiManager("UseNames", "true");
	roiManager("Show All with labels");

	//Measure the Bleached region
	if (Manual==0) 
		{
		selectWindow(OriImg);
		run("Clear Results");
		roiManager("Select", "0");
		roiManager("multi-measure measure_all one append");
		for (i = 0; i < frames; i++) {frap[i]=getResult("Mean(FRAP)", i);}
		}
		
	//Measure the acquisitional bleaching
	if (Corr_Bleach==1)
		{
		selectWindow(OriImg);
		run("Clear Results");
		roiManager("Select", "1");
		roiManager("multi-measure measure_all one append");
		for (i = 0; i < frames; i++) {bleach[i]=getResult("Mean(Ref_Cell)",i);}
		}
		
	//Measure the background
	if (BG_Value==-1)
		{
		selectWindow(OriImg);
		run("Clear Results");
		roiManager("Select", "2");
		roiManager("multi-measure measure_all one append");
		for (i = 0; i < frames; i++) {backgrd[i]=getResult("Mean(BG)", i);}
		}
	else {for (i = 0; i < frames; i++) {backgrd[i]=BG_Value;}}

	run("Clear Results");
	
	if (Manual==1)
		{
		//Perform the manual tracking of the bleached region
		selectWindow(OriImg);
		Stack.setFrame(BE);
		run("Clear Results");
		roiManager("reset");
		run("Select None");
		RoiManager.associateROIsWithSlices(true);
		RoiManager.useNamesAsLabels(false);
		roiManager("Show All with labels");
		setTool("zoom");
		Frame = BE;
		
		waitForUser("Manual tracking - Let's get ready!", "First, zoom and center the region of interest ! \n When done Click 'OK' to start ! \n You just have to click in the center of the bleachnig region until you reached the end of the timelapse ! \n Good luck!");
		setTool("point");
		Stack.setFrame(BE);

		while (Frame <= frames)
			{
			if (selectionType()==10)
				{
				roiManager("add");
				Frame = Frame + 1;
				run("Select None");
				run("Next Slice [>]");
				}
			}
		NbROI = roiManager("count");
		for (post = 0; post < NbROI; post++)
			{
			roiManager("Select", post);
			getSelectionBounds(x, y, width, height);
			run("Specify...", "width=BRw height=BRh x=x y=y oval centered");
			MeanVal = getValue("Mean");
			frap[BE+post-1]=MeanVal;
			}
		roiManager("Deselect");
		if (channels > 1){roiManager("Save", path+File.separator+name+"_"+ChName+"_Manual_Track_RoiSet.zip");}
		else {roiManager("Save", path+File.separator+name+"_Manual_Track_RoiSet.zip");}
		selectWindow(OriImg);
		Stack.setFrame(BE);
		run("Clear Results");
		roiManager("reset");
		run("Select None");
		setTool("point");
		Frame = BE;
		
		showMessage("Manual tracking again!", "Now we will follow the bleached region before the bleachnig event (to perform normalization of the data).\nClick in the center of the bleachnig region untill you reach the beginning of the timelapse ! \nLet's get ready!");
		setTool("point");
		Stack.setFrame(BE);

		while (Frame > 0)
			{
			if (selectionType()==10)
				{
				roiManager("add");
				Frame = Frame -1;
				run("Select None");
				run("Previous Slice [<]");
				}
			}
		NbROI = roiManager("count");
		for (pre = 0; pre < NbROI; pre++)
			{
			roiManager("Select", pre);
			getSelectionBounds(x, y, width, height);
			run("Specify...", "width=BRw height=BRh x=x y=y oval centered");
			MeanVal = getValue("Mean");
			frap[BE-pre-1]=MeanVal;
			}
		}

// Result table generation + corrections
	for (i = 0; i < frames; i++)
		{
		time[i]= (deltaT[i]-deltaT[BE-1]);
		if (Corr_Bleach==1){frap_corr[i]=(frap[i]-backgrd[i])/(bleach[i]-backgrd[i]);}
		else if (Corr_Bleach==0){frap_corr[i]=(frap[i]-backgrd[i]);} 
		setResult("Time", i, time[i]);
		setResult("FRAP", i, frap[i]);
		setResult("Ref_Cell", i, bleach[i]);
		setResult("BG", i, backgrd[i]);
		setResult("FRAP_corr", i, frap_corr[i]);
		}

// Normalize the data around 1 before the bleaching
	if (Live == 0)
		{
		beforemean = newArray(frames-(frames-(BE-1)));
		for (k = 0 ; k < BE-1; k++){beforemean[k]=frap_corr[k];}
		}
	else if (Live == 1)
		{
		beforemean = newArray(frames-(frames-(BBE-1)));
		for (k = 0 ; k < BBE-1; k++){beforemean[k]=frap_corr[k];}			
		}
	Array.getStatistics(beforemean, min, max, BeforeMean, stdDev);
	for (j = 0; j < frames; j++)
		{
		frap_corr_norm[j]=frap_corr[j]/BeforeMean;
		setResult("FRAP_corr_Norm", j, frap_corr_norm[j]);	
		}
		
// Normalize the data between O and 1		
	// Normalisation at 0 post bleach
	for (w =0; w<frames; w++){frap_corr_2xnorm[w] = frap_corr[w]-frap_corr[BE-1];}
	// Normalize the data around 1 before the bleaching
	if (Live == 0)
		{
		beforemean2 = newArray(frames-(frames-(BE-1)));
		for (z = 0 ; z < BE-1; z++){beforemean2[z]=frap_corr_2xnorm[z];}
		}
	if (Live == 1)
		{
		beforemean2 = newArray(frames-(frames-(BBE-1)));
		for (z = 0 ; z < BBE-1; z++){beforemean2[z]=frap_corr_2xnorm[z];}	
		}
	Array.getStatistics(beforemean2, min2, max2, BeforeMean2, stdDev2);
	for (a = 0; a < frames; a++)
		{
		frap_corr_2xnorm[a]=frap_corr_2xnorm[a]/BeforeMean2;
		setResult("FRAP_corr_2xNorm", a, frap_corr_2xnorm[a]);	
		}

// Plot all the results
	Plot.create("Plot", "t ("+TimeUnit+")", "Raw Intensity" ,time, frap);
	Plot.setColor("red");
	Plot.add("circles", time, frap);
	Plot.setStyle(1, "red,none,4.0,Dot");
	Plot.setColor("black");
	Array.getStatistics(time, minT, maxT, BeforeMean, stdDev);
	Plot.update();
	Plot.makeHighResolution("Raw_Data",2.0);
	close("Plot");

	Plot.create("Plot", "t ("+TimeUnit+")", "Intensity corrected + single normalization" ,time, frap_corr_norm);
	Plot.setColor("red");
	Plot.add("circles", time, frap_corr_norm);
	Plot.setStyle(1, "red,none,4.0,Dot");
	Plot.setColor("black");
	Array.getStatistics(time, minT, maxT, BeforeMean, stdDev);
	Plot.setLimits(minT, maxT, 0, 1.2);
	Plot.update();
	Plot.makeHighResolution("Corrected_Single_Norm",2.0);
	close("Plot");

	Plot.create("Plot", "t ("+TimeUnit+")", "Intensity corrected + double normalization" ,time, frap_corr_2xnorm);
	Plot.setColor("red");
	Plot.add("circles", time, frap_corr_2xnorm);
	Plot.setStyle(1, "red,none,4.0,Dot");
	Plot.setColor("black");
	Array.getStatistics(time, minT, maxT, BeforeMean, stdDev);
	Plot.setLimits(minT, maxT, 0, 1.2);
	Plot.update();
	Plot.makeHighResolution("Corrected_Double_Norm",2.0);
	close("Plot");

	run("Concatenate...", "  title=FRAP_Curves open image1=Raw_Data image2=Corrected_Single_Norm image3=Corrected_Double_Norm image4=[-- None --]");
	if (channels > 1){saveAs("TIFF", path+File.separator+name+"_"+ChName+"_FRAP_Plots");}
	else {saveAs("TIFF", path+File.separator+name+"_FRAP_Plots");}
	rename("All_plots");
	setSlice(2);
	
	Dialog.create("Analysis method");
	Dialog.addMessage("Select an equation to perform a fitting of your recovery data.");
	Dialog.addChoice("Fit equation" , newArray("Single exponential", "Double exponential"));
	Dialog.show();
	FitMeth = Dialog.getChoice();
	close("All_plots");

// Fit FRAP corrected and normalized :
	if (FitMeth == "Single exponential")
		{
		// Fitting using a single exponential function : F(t)=(Finf-F0)*(1-exp(-kt)+F0")
		Fit.doFit("y=-a*exp(-b*x)+c", Array.slice(time,BE-1,frames), Array.slice(frap_corr_norm,BE-1,frames));
	
		// Estimation of Tau 1/2, infinity & visible:
		//    When the plateau is never acchieved using the fit (at infinity) it provides aberant values of the max recovery (and also wrong t 1/2 values)
		//    Tau 1/2 "visible" only uses the visible part of the fit to find the Tau 1/2 (less risk of errors) but less precise.
		a=Fit.p(0);
		b=Fit.p(1);
		c=Fit.p(2);
		r2=Fit.rSquared;// For Fitting quality evaluation


		iTau_infinity=((c-frap_corr_norm[BE-1])/2)+frap_corr_norm[BE-1]; // Intensity at T 1/2 based on the fit at infinity
		Tau_infinity=(log((iTau_infinity-c)/-a)/-b); // T 1/2 value based on the fit at infinity
	
		iMax_visu = -a*exp(-b*time[frames-1])+c; // Intensity at the last frame of the experiment (on the fitted curve)
		itau_visu = ((iMax_visu-frap_corr_norm[BE-1])/2)+frap_corr_norm[BE-1]; // Intensity at T 1/2 based on the the last frame of the experiment (iMax_visu value found on the fitted curve).
		tau_visu=(log((itau_visu-c)/-a)/-b); // T 1/2 value from the visible part of the fit
	
    	// Calculation of the mobile fraction (recovery between the intensity after the bleach event and the plateau)
		M_F_infinity=(c-frap_corr_norm[BE-1])/(1-frap_corr_norm[BE-1]); // Mobile fraction estimated using the fit at infinity
		M_F_visu=(iMax_visu-frap_corr_norm[BE-1])/(1-frap_corr_norm[BE-1]);  // Mobile fraction estimated using the visible part of the fit
	
		// Warning : strange values
		if (M_F_infinity >1.2 || M_F_visu > 1.2){showMessage("Warning! The recovery is higher than 100%...");}
		if (M_F_infinity <0.3 || M_F_visu <0.3){showMessage("The recovery is very low...");}
		}
	
	else if (FitMeth == "Double exponential")
		{
		// Fitting using a double exponential function  
		Fit.doFit("y = a*exp(-b*x)+c*exp(-d*x)+e", Array.slice(time,BE-1,frames), Array.slice(frap_corr_norm,BE-1,frames));	
	
		// T 1/2 calculation
		Tau_infinity=0;
		x=0.1;
		a=Fit.p(0);
		b=Fit.p(1);
		c=Fit.p(2);
		d=Fit.p(3);
		e=Fit.p(4);
    	r2=Fit.rSquared; // Fitting quality evaluation

    	iTau_infinity=((e-frap_corr_norm[BE-1])/2)+frap_corr_norm[BE-1]; // Intensity at T 1/2 based on the fit at infinity
            
    	itau=a*exp(-b*x)+c*exp(-d*x)+e; // Optimal fit equation
    	iMax_visu = a*exp(-b*time[frames-1])+c*exp(-d*time[frames-1])+e; // Intensity at the last frame of the experiment (on the fitted curve)
    
		while(itau<=iTau_infinity)
			{
	 		if (x<1000) // 1000 = Limit (in TimeUnit) to avoid  infinite calculation
		 		{
	 	    	Tau_infinity=x;
	 	    	itau=a*exp(-b*x)+c*exp(-d*x)+e;
	 	    	x=x+0.01; // 0.01 is the step to search iTau_infinity on the curve
	 			}
	 		else if ( x>1000 || itau<0 || x<0)
	        	{ 
		    	itau=iTau_infinity+1;
		    	showMessage("Error, the recovery doesn't reach any plateau");
		    	print ("itau=",itau);
	        	}
	    	}

	 	y=0.1;
	 	tau_visu=0;
	 	itau_visu = ((iMax_visu-frap_corr_norm[BE-1])/2)+frap_corr_norm[BE-1]; // Intensity at T 1/2 based on the the last frame of the experiment (iMax_visu value found on the fitted curve).
	 	itau2 =a*exp(-b*y)+c*exp(-d*y)+e;

	 	while(itau2<=itau_visu)
	 		{
	 		if (y>1000) // 1000 = Limit (in TimeUnit) to avoid  infinite calculation
	 			{
	 			itau2=itau_visu+1;
	 			}
	 	    tau_visu=y;
	 	    itau2=a*exp(-b*y)+c*exp(-d*y)+e;
	 	    y=y+0.01;  // 0.01 is the step to search iTau_infinity on the curve
	 		}
	 
	 	// Calculation of the mobile fraction (recovery between the intensity after the bleach event and the plateau)
	 	M_F_infinity=(e-frap_corr_norm[BE-1])/(1-frap_corr_norm[BE-1]); // Mobile fraction estimated using the fit at infinity
	 	M_F_visu=(iMax_visu-frap_corr_norm[BE-1])/(1-frap_corr_norm[BE-1]); // Mobile fraction estimated using the visible part of the fit
	  
	 	// Warning : strange values
     	if (M_F_infinity >1.2 || M_F_visu > 1.2){showMessage("Warning! The recovery is higher than 100%...");}
		if (M_F_infinity <0.3 || M_F_visu <0.3){showMessage("The recovery is very low...");}
     }

//Plot the result of the fitting		
	Fit.plot;
	rename("Fit_Plot");
	Plot.setStyle(0, "black,none,1.5,Line");
	Plot.setStyle(1, "red,black,4.0,Dot");
	Plot.setStyle(2, "black,none,1.0,Line");
	xValues = newArray(Tau_infinity,Tau_infinity);
	yValues = newArray(0,iTau_infinity);
	Plot.add("line",xValues, yValues);
	Plot.setStyle(3, "blue,none,1.0,Line");
	xValues = newArray(Tau_infinity,Tau_infinity);
	yValues = newArray(iTau_infinity,iTau_infinity);
	Plot.add("circle", xValues, yValues);
	Plot.setStyle(4,"blue,blue,2.0,Circle");
	
	Plot.addText("t 1/2",((Tau_infinity/frames)+0.08),(1-(iTau_infinity/2.4)));
	Plot.setLimits(0, maxT, 0, 1.2);
	
	Plot.makeHighResolution("Fit_Plot",2.0);
	if (channels > 1){saveAs("TIFF", path+File.separator+name+"_"+ChName+"_expFit");}
	else {saveAs("TIFF", path+File.separator+name+"_expFit");}
	close("Fit_Plot");
	
//Print Bleaching efficiency & Fit
	print(" ");
	print("   Bleaching Efficiency : ",(1-(frap_corr_norm[BE-1]))*100+" %");
	print(" ");
	print("   Fitting equation : "+FitMeth);
	
	Array.getStatistics(time, min, maxT, BeforeMean, stdDev);
	
// Fitting quality evaluation 
	if (r2<1.25 && r2>=0.75)
		{
		showMessage("Good fitting \nR² = "+r2);
		print("   Fitting quality : Good.");
		print("      R² : ",r2);
		}
	else
		{
		showMessage("Warning!\nPoor fitting \n R² = "+r2);
		print("   Fitting quality : Poor.");
		print("      R² : ",r2); 
		}
	print(" ");
	
	setResult("Tau1/2_(infinity)",0, Tau_infinity);
	setResult("Mobile-Fraction_(infinity)",0, M_F_infinity);
	setResult("Tau1/2_(visible)",0, tau_visu);
	setResult("Mobile-Fraction_(visible)",0, M_F_visu );
	setResult("Bleaching_Intensity",0, frap_corr_norm[BE-1]);

// Check if the plateau is reached during the acquisition
	if (FitMeth == "Single exponential")
		{PltReached = iMax_visu/c;}
	else if (FitMeth == "Double exponential")
		{PltReached = iMax_visu/e;}
		
	PltReached = (PltReached*100);
		
	if (PltReached < 95) 
		{
		print("   Warning : the plateau is not reached during the acquisition !");
		print("   Plateau vizualized is at "+d2s(PltReached,2)+"% (compared to the fit at t = +infinity.)");
		}
	else if (PltReached >= 95)
		{
		print("   Perfect : the plateau is reached during the acquisition !");
		print("   Plateau vizualized is at "+d2s(PltReached,2)+"% (compared to the fit at t = +infinity.)");
		}
	print("");
	print("FRAP Analysis results :"); 	
	print("   Tau 1/2 (infinity) : ",Tau_infinity+" "+TimeUnit);
	print("   Mobile fraction : ",M_F_infinity*100+" %");
	//print("   Intensity at Tau 1/2 (infinity) : ",t+" "+ "Unit?");
	print(" ");
	print("If the plateau is not reached at intinity the fit values will be aberrant !");
	print("In this case use the following values, obtained on the visible part of the fit!");
	print("   Tau 1/2 (visible) : ",tau_visu+" "+TimeUnit);	
	print("   Mobile fraction (visible) : ",M_F_visu*100+" %");
	//print("   Intensity at Tau 1/2 (visible) : ",itau_visu+" "+"Unit?");
	//print("   Max Intensity (visible) : ",iMax_visu);

	selectWindow("Results");
	if (channels > 1){saveAs("Results", path+File.separator+name+"_"+ChName+".xls");}
	else{saveAs("Results", path+File.separator+name+".xls");}
	close("Results");
	
	selectWindow("Log");
	if (channels > 1){saveAs("Text", path+File.separator+name+"_"+ChName+"_Log.txt");}
	else {saveAs("Text", path+File.separator+name+"_Log.txt");}

	
	