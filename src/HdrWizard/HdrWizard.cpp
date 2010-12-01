/**
 * This file is a part of Luminance HDR package.
 * ----------------------------------------------------------------------
 * Copyright (C) 2006,2007 Giuseppe Rota
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 * ----------------------------------------------------------------------
 *
 * Original Work
 * @author Giuseppe Rota <grota@users.sourceforge.net>
 * Improvements, bugfixing
 * @author Franco Comida <fcomida@users.sourceforge.net>
 *
 */

#include <QStringList>
#include <QFileDialog>
#include <QDir>
#include <QUrl>
#include <QMessageBox>
#include <QProcess>
#include <QTextStream>

#include "arch/freebsd/math.h"

#include "Common/config.h"
#include "EditingTools.h"
#include "HdrWizard.h"

#include <iostream>

enum {LDR_INPUT_TYPE,MDR_INPUT_TYPE,UNKNOWN_INPUT_TYPE};

HdrWizard::HdrWizard(QWidget *p, QStringList files) : QDialog(p), hdrCreationManager(NULL), loadcurvefilename(""), savecurvefilename("") {
	setupUi(this);
	setAcceptDrops(true);

	weights_in_gui[0]=TRIANGULAR;
	weights_in_gui[1]=GAUSSIAN;
	weights_in_gui[2]=PLATEAU;
	responses_in_gui[0]=GAMMA;
	responses_in_gui[1]=LINEAR;
	responses_in_gui[2]=LOG10;
	responses_in_gui[3]=FROM_ROBERTSON;
	models_in_gui[0]=DEBEVEC;
	models_in_gui[1]=ROBERTSON;

	tableWidget->setHorizontalHeaderLabels(QStringList()<< tr("Image Filename") << tr("Exposure"));
	tableWidget->resizeColumnsToContents();
	
	EVgang = new Gang(EVSlider, ImageEVdsb, NULL, NULL, NULL,NULL, -10,10,0);

	hdrCreationManager = new HdrCreationManager();

	if (files.size()) {
		loadInputFiles(files, files.size());
	}

	luminance_options=LuminanceOptions::getInstance();

	setupConnections();
}

HdrWizard::~HdrWizard() {
	std::cout << "HdrWizard::~HdrWizard()" << std::endl;
	
	QStringList  fnames = hdrCreationManager->getFileList();
	int n = fnames.size();
	
	for (int i=0; i<n; i++) {
		QString fname = hdrCreationManager->getFileList().at(i);
		QFileInfo qfi(fname);
		QString thumb_name = QString(luminance_options->tempfilespath + "/"+  qfi.completeBaseName() + ".thumb.jpg");
		QFile::remove(thumb_name);
		thumb_name = QString(luminance_options->tempfilespath + "/" + qfi.completeBaseName() + ".thumb.ppm");
		QFile::remove(thumb_name);
	}

	delete EVgang;
	delete hdrCreationManager;
}

void HdrWizard::setupConnections() {
	connect(EVgang, SIGNAL(finished()), this, SLOT(editingEVfinished()));
	connect(tableWidget, SIGNAL(currentCellChanged(int,int,int,int)), this, SLOT(inputHdrFileSelected(int)));

	connect(NextFinishButton,SIGNAL(clicked()),this,SLOT(NextFinishButtonClicked()));
	connect(cancelButton,SIGNAL(clicked()),this,SLOT(reject()));
	connect(pagestack,SIGNAL(currentChanged(int)),this,SLOT(currentPageChangedInto(int)));

	connect(predefConfigsComboBox,SIGNAL(activated(int)),this,
	SLOT(predefConfigsComboBoxActivated(int)));
	connect(antighostRespCurveCombobox,SIGNAL(activated(int)),this,
	SLOT(antighostRespCurveComboboxActivated(int)));
	connect(customConfigCheckBox,SIGNAL(toggled(bool)),this,
	SLOT(customConfigCheckBoxToggled(bool)));
	connect(triGaussPlateauComboBox,SIGNAL(activated(int)),this,
	SLOT(triGaussPlateauComboBoxActivated(int)));
	connect(predefRespCurveRadioButton,SIGNAL(toggled(bool)),this,
	SLOT(predefRespCurveRadioButtonToggled(bool)));
	connect(gammaLinLogComboBox,SIGNAL(activated(int)),this,
	SLOT(gammaLinLogComboBoxActivated(int)));
	connect(loadRespCurveFromFileCheckbox,SIGNAL(toggled(bool)),this,
	SLOT(loadRespCurveFromFileCheckboxToggled(bool)));
	connect(loadRespCurveFileButton,SIGNAL(clicked()),this,
	SLOT(loadRespCurveFileButtonClicked()));
	connect(saveRespCurveToFileCheckbox,SIGNAL(toggled(bool)),this,
	SLOT(saveRespCurveToFileCheckboxToggled(bool)));
	connect(saveRespCurveFileButton,SIGNAL(clicked()),this,
	SLOT(saveRespCurveFileButtonClicked()));
	connect(modelComboBox,SIGNAL(activated(int)),this,
	SLOT(modelComboBoxActivated(int)));
	connect(RespCurveFileLoadedLineEdit,SIGNAL(textChanged(const QString&)),this,
	SLOT(loadRespCurveFilename(const QString&)));
	connect(loadImagesButton,SIGNAL(clicked()),this,SLOT(loadImagesButtonClicked()));
	connect(hdrCreationManager, SIGNAL(fileLoaded(int,QString,float)), this, SLOT(fileLoaded(int,QString,float)));
	connect(hdrCreationManager,SIGNAL(finishedLoadingInputFiles(QStringList)),this, SLOT(finishedLoadingInputFiles(QStringList)));
	connect(hdrCreationManager,SIGNAL(errorWhileLoading(QString)),this, SLOT(errorWhileLoading(QString)));
	connect(hdrCreationManager,SIGNAL(expotimeValueChanged(float,int)),this, SLOT(updateGraphicalEVvalue(float,int)));
	connect(hdrCreationManager, SIGNAL(finishedAligning()), this, SLOT(finishedAligning()));
	connect(hdrCreationManager, SIGNAL(ais_failed(QProcess::ProcessError)), this, SLOT(ais_failed(QProcess::ProcessError)));

	connect(this,SIGNAL(rejected()),hdrCreationManager,SLOT(removeTempFiles()));

}

void HdrWizard::loadImagesButtonClicked() {
    QString filetypes;
    // when changing these filetypes, also change in DnDOption - for Drag and Drop
    filetypes += tr("All formats (*.jpeg *.jpg *.tiff *.tif *.crw *.cr2 *.nef *.dng *.mrw *.orf *.kdc *.dcr *.arw *.raf *.ptx *.pef *.x3f *.raw *.sr2 *.rw2 *.3fr *.mef *.mos *.erf *.raw *.nrw");
    filetypes += tr("*.JPEG *.JPG *.TIFF *.TIF *.CRW *.CR2 *.NEF *.DNG *.MRW *.ORF *.KDC *.DCR *.ARW *.RAF *.PTX *.PEF *.X3F *.RAW *.SR2 *.RW2 *.3FR *.MEF *.MOS *.ERF *.RAW *.NRW);;");
    filetypes += tr("JPEG (*.jpeg *.jpg *.JPEG *.JPG);;");
    filetypes += tr("TIFF Images (*.tiff *.tif *.TIFF *.TIF);;");
    filetypes += tr("RAW Images (*.crw *.cr2 *.nef *.dng *.mrw *.orf *.kdc *.dcr *.arw *.raf *.ptx *.pef *.x3f *.raw *.sr2 *.rw2 *.3fr *.mef *.mos *.erf *.raw *.nrw");
    filetypes += tr("*.CRW *.CR2 *.NEF *.DNG *.MRW *.ORF *.KDC *.DCR *.ARW *.RAF *.PTX *.PEF *.X3F *.RAW *.SR2 *.RW2 *.3FR *.MEF *.MOS *.ERF *.RAW *.NRW)");

    QString RecentDirInputLDRs = settings.value(KEY_RECENT_PATH_LOAD_LDRs_FOR_HDR, QDir::currentPath()).toString();

    QStringList files = QFileDialog::getOpenFileNames(this, tr("Select the input images"), RecentDirInputLDRs, filetypes );

    if (!files.isEmpty() ) {
	QFileInfo qfi(files.at(0));
	// if the new dir, the one just chosen by the user, is different from the one stored in the settings, update the settings.
	if (RecentDirInputLDRs != qfi.path()) {
		// update internal field variable
		RecentDirInputLDRs=qfi.path();
		settings.setValue(KEY_RECENT_PATH_LOAD_LDRs_FOR_HDR, RecentDirInputLDRs);
	}
	loadImagesButton->setEnabled(false);
	loadInputFiles(files, files.count());
	QApplication::setOverrideCursor(QCursor(Qt::BusyCursor));
    } //if (!files.isEmpty())
}

void HdrWizard::dragEnterEvent(QDragEnterEvent *event) {
	if (loadImagesButton->isEnabled())
		event->acceptProposedAction();
}

void HdrWizard::dropEvent(QDropEvent *event) {

	if (event->mimeData()->hasUrls()) {
		QStringList files = convertUrlListToFilenameList(event->mimeData()->urls());
		if (files.size() > 0)
			loadInputFiles(files, files.size());
	}
	event->acceptProposedAction();
}

void HdrWizard::loadInputFiles(QStringList files, int count) {
	tableWidget->setEnabled(false);
	tableWidget->setRowCount(count);
	progressBar->setMaximum(count);
	progressBar->setValue(0);

	hdrCreationManager->setFileList(files);
	hdrCreationManager->loadInputFiles();
}

void HdrWizard::fileLoaded(int index, QString fname, float expotime) {
	qDebug("WIZ: fileLoaded, expotimes[%d]=%f --- EV=%f",index,expotime,log2f(expotime));
	updateGraphicalEVvalue(expotime,index);
	//fill graphical list
	QFileInfo qfi(fname);
	tableWidget->setItem(index,0,new QTableWidgetItem(qfi.fileName()));
	progressBar->setValue(progressBar->value()+1); // increment progressbar
}

void HdrWizard::finishedLoadingInputFiles(QStringList filesLackingExif) {
	if (filesLackingExif.size()==0) {
		NextFinishButton->setEnabled(true);
		confirmloadlabel->setText(tr("<center><font color=\"#008400\"><h3><b>Images Loaded.</b></h3></font></center>"));
	} else {
		QString warning_message=(QString(tr("<font color=\"#FF0000\"><h3><b>WARNING:</b></h3></font>\
		Luminance HDR was not able to find the relevant <i>EXIF</i> tags\nfor the following images:\n <ul>\
		%1</ul>\
		<hr>You can still proceed creating an Hdr. To do so you have to insert <b>manually</b> the EV (exposure values) or stop difference values.\
		<hr>If you want Qtfsgui to do this <b>automatically</b>, you have to load images that have at least\nthe following exif data: \
		<ul><li>Shutter Speed (seconds)</li>\
		<li>Aperture (f-number)</li></ul>\
		<hr><b>HINT:</b> Losing EXIF data usually happens when you preprocess your pictures.<br>\
		You can perform a <b>one-to-one copy of the exif data</b> between two sets of images via the <i><b>\"Tools->Copy Exif Data...\"</b></i> menu item."))).arg(filesLackingExif.join(""));
		QMessageBox::warning(this,tr("EXIF data not found"),warning_message);
		confirmloadlabel->setText(QString(tr("<center><h3><b>To proceed you need to manually set the exposure values.<br><font color=\"#FF0000\">%1</font> values still required.</b></h3></center>")).arg(filesLackingExif.size()));
	}
	//do not load any more images
	//loadImagesButton->setEnabled(false);
	//graphical fix
	tableWidget->resizeColumnsToContents();
	//enable user EV input
	EVgroupBox->setEnabled(true);
	tableWidget->selectRow(0);
	tableWidget->setEnabled(true);

	//FIXME mtb doesn't work with 16bit data yet (and probably ever)
	if ((tableWidget->rowCount()>=2) && (hdrCreationManager->inputImageType() == LDR_INPUT_TYPE)) {
		alignCheckBox->setEnabled(true);
		alignGroupBox->setEnabled(true);
	}
	else if ((tableWidget->rowCount()>=2) && (hdrCreationManager->inputImageType() == MDR_INPUT_TYPE)) {
		alignCheckBox->setEnabled(true);
		alignGroupBox->setEnabled(true);
		mtb_radioButton->setEnabled(false);
	}
	QApplication::restoreOverrideCursor();
}

void HdrWizard::errorWhileLoading(QString error) {
	tableWidget->clear();
	tableWidget->setRowCount(0);
	tableWidget->setEnabled(true);
	progressBar->setValue(0);
	QMessageBox::critical(this,tr("Loading Error"), error);
	hdrCreationManager->clearlists(true);
}

void HdrWizard::updateGraphicalEVvalue(float expotime, int index_in_table) {
	qDebug("WIZ: updateGraphicalEVvalue EV[%d]=%f",index_in_table,log2f(expotime));
	if (expotime!=-1) {
		QString EVdisplay;
		QTextStream ts(&EVdisplay);
		ts.setRealNumberPrecision(2);
		ts << right << forcesign << fixed << log2f(expotime) << " EV";
		QTableWidgetItem *tableitem=new QTableWidgetItem(EVdisplay);
		tableitem->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
		tableWidget->setItem(index_in_table,1,tableitem);
	} else {
		//if image doesn't contain (the required) exif tags
		QTableWidgetItem *tableitem=new QTableWidgetItem(QString(tr("Unknown")));
		tableitem->setTextAlignment(Qt::AlignRight | Qt::AlignVCenter);
		tableitem->setBackground(QBrush(Qt::yellow));
		tableitem->setForeground(QBrush(Qt::red));
		tableWidget->setItem(index_in_table,1,tableitem);
	}
}

void HdrWizard::finishedAligning() {
	QApplication::restoreOverrideCursor();
	NextFinishButton->setEnabled(true);
	pagestack->setCurrentIndex(2);
}

void HdrWizard::ais_failed(QProcess::ProcessError e) {
	switch (e) {
	case QProcess::FailedToStart:
		QMessageBox::warning(this,tr("Error..."),tr("Failed to start external application \"<em>align_image_stack</em>\".<br>Please read \"Help -> Documentation... -> Hints and tips\" for more information."));
	break;
	case QProcess::Crashed:
		QMessageBox::warning(this,tr("Error..."),tr("The external application \"<em>align_image_stack</em>\" crashed..."));
	break;
	case QProcess::Timedout:
	case QProcess::ReadError:
	case QProcess::WriteError:
	case QProcess::UnknownError:
		QMessageBox::warning(this,tr("Error..."),tr("An unknown error occurred while executing the \"<em>align_image_stack</em>\" application..."));
	break;
	}
	QApplication::restoreOverrideCursor();
	NextFinishButton->setEnabled(true);
	if (pagestack->currentIndex()==0)
		pagestack->setCurrentIndex(1);
}

void HdrWizard::customConfigCheckBoxToggled(bool want_custom) {
	if (!want_custom) {
		if (!antighostingCheckBox->isChecked()) {
			label_RespCurve_Antighost->setDisabled(true);
			antighostRespCurveCombobox->setDisabled(true);
			label_Iterations->setDisabled(true);
			spinBoxIterations->setDisabled(true);
			//temporary disable anti-ghosting until it's fixed
			antighostingCheckBox->setDisabled(true);
		}
		else {
			label_predef_configs->setDisabled(true);
			predefConfigsComboBox->setDisabled(true);
			label_weights->setDisabled(true);
			lineEdit_showWeight->setDisabled(true);
			label_resp->setDisabled(true);
			lineEdit_show_resp->setDisabled(true);
			label_model->setDisabled(true);
			lineEdit_showmodel->setDisabled(true);
		}
		predefConfigsComboBoxActivated(predefConfigsComboBox->currentIndex());
		NextFinishButton->setText(tr("&Finish"));
	} else {
		NextFinishButton->setText(tr("&Next >"));
	}
}

void HdrWizard::predefRespCurveRadioButtonToggled(bool want_predef_resp_curve) {
	if (want_predef_resp_curve) {
		//ENABLE load_curve_button and lineedit when "load from file" is checked.
		if (!loadRespCurveFromFileCheckbox->isChecked()) {
			loadRespCurveFileButton->setEnabled(false);
			RespCurveFileLoadedLineEdit->setEnabled(false);
		}
		loadRespCurveFromFileCheckboxToggled(loadRespCurveFromFileCheckbox->isChecked());
	} else { //want to recover response curve via robertson02
		//update hdrCreationManager->chosen_config
		hdrCreationManager->chosen_config.response_curve=FROM_ROBERTSON;
		//always enable
		NextFinishButton->setEnabled(true);
		saveRespCurveToFileCheckboxToggled(saveRespCurveToFileCheckbox->isChecked());
	}
}

void HdrWizard::loadRespCurveFromFileCheckboxToggled( bool checkedfile ) {
    //if checkbox is checked AND we have a valid filename
    if (checkedfile && loadcurvefilename != "") {
	//update chosen config
	hdrCreationManager->chosen_config.response_curve=FROM_FILE;
	hdrCreationManager->chosen_config.LoadCurveFromFilename=strdup(QFile::encodeName(loadcurvefilename).constData());
	//and ENABLE nextbutton
	NextFinishButton->setEnabled(true);
    }
    //if checkbox is checked AND no valid filename
    else  if (checkedfile && loadcurvefilename == "") {
	// DISABLE nextbutton until situation is fixed
	NextFinishButton->setEnabled(false);
// 	qDebug("Load checkbox is checked AND no valid filename");
    }
    //checkbox not checked
    else {
	// update chosen config
	hdrCreationManager->chosen_config.response_curve=responses_in_gui[gammaLinLogComboBox->currentIndex()];
	hdrCreationManager->chosen_config.LoadCurveFromFilename="";
	//and ENABLE nextbutton
	NextFinishButton->setEnabled(true);
    }
}

void HdrWizard::saveRespCurveToFileCheckboxToggled( bool checkedfile ) {
	//if checkbox is checked AND we have a valid filename
	if (checkedfile && savecurvefilename != "") {
		hdrCreationManager->chosen_config.SaveCurveToFilename=strdup(QFile::encodeName(savecurvefilename).constData());
		NextFinishButton->setEnabled(true);
	}
	//if checkbox is checked AND no valid filename
	else  if (checkedfile && savecurvefilename == "") {
		// DISABLE nextbutton until situation is fixed
		NextFinishButton->setEnabled(false);
	}
	//checkbox not checked
	else {
		hdrCreationManager->chosen_config.SaveCurveToFilename="";
		//and ENABLE nextbutton
		NextFinishButton->setEnabled(true);
	}
}

void HdrWizard::NextFinishButtonClicked() {
	int currentpage=pagestack->currentIndex();
	switch (currentpage) {
	case 0:
		pagestack->setCurrentIndex(1);
		NextFinishButton->setDisabled(true);
		break;
	case 1:
		//now align, if requested
		if (alignCheckBox->isChecked()) {
			QApplication::setOverrideCursor(QCursor(Qt::BusyCursor));
			confirmloadlabel->setText("<center><h3><b>"+tr("Aligning...")+"</b></h3></center>");
			NextFinishButton->setDisabled(true);
			alignGroupBox->setDisabled(true);
			EVgroupBox->setDisabled(true);
			tableWidget->setDisabled(true);
			this->repaint();
			if (ais_radioButton->isChecked())
				hdrCreationManager->align_with_ais();
			else
				hdrCreationManager->align_with_mtb();

//			switch (alignmentEngineCB->currentIndex()) {
//				case 0: //Hugin's align_image_stack
//				hdrCreationManager->align_with_ais();
//				break;
//				case 1:
// 				if (hdrCreationManager->inputImageType()==HdrCreationManager::MDR_INPUT_TYPE) {
// 					QMessageBox::warning(this,tr("Error..."),tr("MTB is not available with 16 bit input images."));
// 					return;
// 				}
//				hdrCreationManager->align_with_mtb();
//				break;
//			}
			return;
		}
		pagestack->setCurrentIndex(2);
		break;
	case 2:
		if(!customConfigCheckBox->isChecked()) {
			currentpage=3;
		} else {
			pagestack->setCurrentIndex(3);
			break;
		}
	case 3:
		QApplication::setOverrideCursor(QCursor(Qt::WaitCursor));
		PfsFrameHDR=hdrCreationManager->createHdr(antighostingCheckBox->isChecked(),spinBoxIterations->value());
		QApplication::restoreOverrideCursor();
		accept();
		return;
	}
}

void HdrWizard::currentPageChangedInto(int newindex) {
	//predefined configs page
	if (newindex==2) {
		hdrCreationManager->removeTempFiles();
		NextFinishButton->setText(tr("&Finish"));
		//when at least 2 LDR inputs perform Manual Alignment
		int numldrs=hdrCreationManager->getLDRList().size();
		if (hdrCreationManager->inputImageType()==HdrCreationManager::LDR_INPUT_TYPE && numldrs>=2) {
			this->setDisabled(true);
			//fix for some platforms/Qt versions: makes sure LDR images have alpha channel
			hdrCreationManager->makeSureLDRsHaveAlpha();
			EditingTools *editingtools= new EditingTools(hdrCreationManager);
			if (editingtools->exec() == QDialog::Accepted) {
				this->setDisabled(false);
			} else {
				emit reject();
			}
			delete editingtools;
		}
	}
	else if (newindex==3) { //custom config
		predefConfigsComboBoxActivated(1);
		NextFinishButton->setText(tr("&Finish"));
		return;
	}
}

void HdrWizard::antighostRespCurveComboboxActivated(int fromgui) {
	gammaLinLogComboBoxActivated(fromgui);
}

void HdrWizard::loadRespCurveFileButtonClicked() {
	loadcurvefilename = QFileDialog::getOpenFileName(
			this,
			tr("Load a camera response curve file"),
			QDir::currentPath(),
			tr("Camera response curve (*.m);;All Files (*)") );
	if (!loadcurvefilename.isEmpty())  {
		RespCurveFileLoadedLineEdit->setText(loadcurvefilename);
		loadRespCurveFromFileCheckboxToggled(loadRespCurveFromFileCheckbox->isChecked());
	}
}

void HdrWizard::saveRespCurveFileButtonClicked() {
	savecurvefilename = QFileDialog::getSaveFileName(
			this,
			tr("Save a camera response curve file"),
			QDir::currentPath(),
			tr("Camera response curve (*.m);;All Files (*)") );
	if (!savecurvefilename.isEmpty())  {
		CurveFileNameSaveLineEdit->setText(savecurvefilename);
		saveRespCurveToFileCheckboxToggled(saveRespCurveToFileCheckbox->isChecked());
	}
}

void HdrWizard::predefConfigsComboBoxActivated( int index_from_gui ) {
	hdrCreationManager->chosen_config=predef_confs[index_from_gui];
	lineEdit_showWeight->setText(getQStringFromConfig(1));
	lineEdit_show_resp->setText(getQStringFromConfig(2));
	lineEdit_showmodel->setText(getQStringFromConfig(3));
}

void HdrWizard::triGaussPlateauComboBoxActivated(int from_gui) {
	hdrCreationManager->chosen_config.weights=weights_in_gui[from_gui];
}

void HdrWizard::gammaLinLogComboBoxActivated(int from_gui) {
	hdrCreationManager->chosen_config.response_curve=responses_in_gui[from_gui];
}

void HdrWizard::modelComboBoxActivated(int from_gui) {
	hdrCreationManager->chosen_config.model=models_in_gui[from_gui];
}

void HdrWizard::loadRespCurveFilename( const QString & filename_from_gui) {
	if (!filename_from_gui.isEmpty()) {
		hdrCreationManager->chosen_config.response_curve=FROM_FILE;
		hdrCreationManager->chosen_config.LoadCurveFromFilename=strdup(QFile::encodeName(filename_from_gui).constData());
	}
}

QString HdrWizard::getCaptionTEXT() {
	return tr("(*) Weights: ")+getQStringFromConfig(1) + tr(" - Response curve: ") + getQStringFromConfig(2) + tr(" - Model: ") + getQStringFromConfig(3);
}

QString HdrWizard::getQStringFromConfig( int type ) {
    if (type==1) { //return String for weights
	switch (hdrCreationManager->chosen_config.weights) {
	case TRIANGULAR:
	    return tr("Triangular");
	case PLATEAU:
	    return tr("Plateau");
	case GAUSSIAN:
	    return tr("Gaussian");
	}
    } else if (type==2) {   //return String for response curve
	switch (hdrCreationManager->chosen_config.response_curve) {
	case LINEAR:
	    return tr("Linear");
	case GAMMA:
	    return tr("Gamma");
	case LOG10:
	    return tr("Logarithmic");
	case FROM_ROBERTSON:
	    return tr("From Calibration");
	case FROM_FILE:
	    return tr("From File");
	}
    } else if (type==3) {   //return String for model
	switch (hdrCreationManager->chosen_config.model) {
	case DEBEVEC:
	    return tr("Debevec");
	case ROBERTSON:
	    return tr("Robertson");
	}
    } else return "";
return "";
}

//triggered by user interaction
void HdrWizard::editingEVfinished() {
	//transform from EV value to expotime value
	hdrCreationManager->setEV(ImageEVdsb->value(),tableWidget->currentRow());
	if (hdrCreationManager->getFilesLackingExif().size()==0) {
		NextFinishButton->setEnabled(true);
		//give an offset to the EV values if they are outside of the -10..10 range.
		hdrCreationManager->checkEVvalues();
		confirmloadlabel->setText(tr("<center><font color=\"#008400\"><h3><b>All the EV values have been set.<br>Now click on Next button.</b></h3></font></center>"));
	} else {
		confirmloadlabel->setText( QString(tr("<center><h3><b>To proceed you need to manually set the exposure values.<br><font color=\"#FF0000\">%1</font> values still required.</b></h3></center>")).arg(hdrCreationManager->getFilesLackingExif().size()) );
	}
}

void HdrWizard::inputHdrFileSelected(int i) {
	if (hdrCreationManager->isValidEV(i))
		ImageEVdsb->setValue(hdrCreationManager->getEV(i));
	if (hdrCreationManager->inputImageType()==HdrCreationManager::LDR_INPUT_TYPE) {
		QImage *image=hdrCreationManager->getLDRList().at(i);
		previewLabel->setPixmap(QPixmap::fromImage(image->scaled(previewLabel->size(), Qt::KeepAspectRatio)));
	}
	else { // load preview from thumbnail previously created on disk
		QString fname = hdrCreationManager->getFileList().at(i);
		QFileInfo qfi(fname);
		QString thumb_name = QString(luminance_options->tempfilespath + "/" + qfi.completeBaseName() + ".thumb.jpg");

		if ( QFile::exists(thumb_name))  {
			QImage thumb_image(thumb_name);
			previewLabel->setPixmap(QPixmap::fromImage(thumb_image.scaled(previewLabel->size(), Qt::KeepAspectRatio)));
		}
		else {
			QString thumb_name = QString(luminance_options->tempfilespath + "/" + qfi.completeBaseName() + ".thumb.ppm");
			if ( QFile::exists(thumb_name))  {
				QImage thumb_image(thumb_name);
				previewLabel->setPixmap(QPixmap::fromImage(thumb_image.scaled(previewLabel->size(), Qt::KeepAspectRatio)));
			}
		}
	}
	ImageEVdsb->setFocus();
}

void HdrWizard::resizeEvent ( QResizeEvent * ) {
	//make sure we ask for a thumbnail only when we need it
	if (pagestack->currentIndex()==0 && tableWidget->currentRow()!=-1 && hdrCreationManager->inputImageType()==HdrCreationManager::LDR_INPUT_TYPE) {
		QImage *image=hdrCreationManager->getLDRList().at(tableWidget->currentRow());
		previewLabel->setPixmap(QPixmap::fromImage(image->scaled(previewLabel->size(), Qt::KeepAspectRatio)));
	}
	else if (pagestack->currentIndex()==0 && tableWidget->currentRow()!=-1 && hdrCreationManager->inputImageType()!=HdrCreationManager::LDR_INPUT_TYPE) { // load preview from thumbnail previously created on disk
		QString fname = hdrCreationManager->getFileList().at(tableWidget->currentRow());
		QFileInfo qfi(fname);
		QString thumb_name = QString(luminance_options->tempfilespath + "/" + qfi.completeBaseName() + ".thumb.jpg");

		if ( QFile::exists(thumb_name))  {
			QImage thumb_image(thumb_name);
			previewLabel->setPixmap(QPixmap::fromImage(thumb_image.scaled(previewLabel->size(), Qt::KeepAspectRatio)));
		}
		else {
			QString thumb_name = QString(luminance_options->tempfilespath + "/" + qfi.completeBaseName() + ".thumb.ppm");
			if ( QFile::exists(thumb_name))  {
				QImage thumb_image(thumb_name);
				previewLabel->setPixmap(QPixmap::fromImage(thumb_image.scaled(previewLabel->size(), Qt::KeepAspectRatio)));
			}
		}
	}
}


void HdrWizard::keyPressEvent(QKeyEvent *event) {
	if (event->key() == Qt::Key_Enter || event->key()==Qt::Key_Return) {
		tableWidget->selectRow(tableWidget->currentRow()==tableWidget->rowCount()-1 ? 0 : tableWidget->currentRow()+1);
	} else if (event->key() == Qt::Key_Escape) {
		emit reject();
	}
}
