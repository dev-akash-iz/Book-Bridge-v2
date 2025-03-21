package com.devakash.book_bridge.pdfProcess.utils;

import com.devakash.book_bridge.pdfProcess.PdfGlobalStore;
import com.tom_roush.pdfbox.pdmodel.PDDocument;
import com.tom_roush.pdfbox.pdmodel.PDPage;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class commonPageBundlerHealper {
	private String fileName ;
	PDDocument successfulPdfBundle = createNewPdf();
	int successfulPageCount = -1;
	int currentBundleNumber = 0;
	long bundleSizeBytes = 0;
	List<String> successfulPdfPaths = new ArrayList<>();

	PDDocument failedPdfBundle = createNewPdf();
	String failedPdfPaths;
	int failedPageCount = -1;
	List<PdfPageBundleInfo> pageBundleInfoList ;

	public commonPageBundlerHealper(String fileName,int pageLength) {
		this.fileName = fileName;
		this.pageBundleInfoList = new ArrayList<>(pageLength+1);
	}

	public static PDDocument createNewPdf() {
		return new PDDocument();
	}

	public void addNewValidPage(PDPage originalPage){
		try {
			if(successfulPdfBundle!=null){
				successfulPdfBundle.addPage(originalPage);
				pageBundleInfoList.add(new PdfPageBundleInfo(true,++successfulPageCount,currentBundleNumber));
			}
		} catch (Exception e) {
			pageBundleInfoList.add(new PdfPageBundleInfo(false,null));
		}
	}


	public void addNewInValidPage(PDPage originalPage){
		try {
			if(failedPdfBundle!=null){
				failedPdfBundle.addPage(originalPage);
				pageBundleInfoList.add(new PdfPageBundleInfo(false,++failedPageCount));
			}
		} catch (Exception e) {
			pageBundleInfoList.add(new PdfPageBundleInfo(false,null));
		}

	}

	public void saveCurrentValidPdfBundle(){
		boolean saved=false;
		if(successfulPageCount>-1){
			File file =  PdfGlobalStore.savePdfToDisk(successfulPdfBundle,"pdf_bundle_"+currentBundleNumber+"_"+fileName);
		    if(file!=null){
				successfulPdfPaths.add(file.getAbsolutePath());
				// after save i need to clear old bundle and add new bundle to update next all page in new bundle
				successfulPdfBundle = createNewPdf(); // passed new bundle refrence so new page all add in this
				successfulPageCount=-1; // new bundle means new page number from 0
				currentBundleNumber++; // increase the bundle number next save is now addtional or previos number
				saved=true;
			}else {
				successfulPdfPaths.add("");
				successfulPdfBundle = createNewPdf(); // passed new bundle refrence so new page all add in this
				successfulPageCount=-1; // new bundle means new page number from 0
				currentBundleNumber++; // increase the bundle number next save is now addtional or previos number
				// doing this in case of saving issue skip this bundle and move for next bundle;
			}
		}else {

		}
//		return saved;
	}

	public void saveInValidPdfBundle(){
		if(failedPageCount>-1){
			File file =  PdfGlobalStore.savePdfToDisk(failedPdfBundle,"failed_pdf_bundle_"+fileName);
			if(file!=null){
				failedPdfPaths =file.getAbsolutePath();
			}else {
				failedPdfPaths=null;
			}
		}else {

		}

	}

	public DetailedDataOFprocessedPDF getFinalFullPDFDetail(){
		return  new DetailedDataOFprocessedPDF(successfulPdfPaths,failedPdfPaths,"",pageBundleInfoList);
	}

	public int getSuccessfulPageCount() {
		return successfulPageCount;
	}
}
