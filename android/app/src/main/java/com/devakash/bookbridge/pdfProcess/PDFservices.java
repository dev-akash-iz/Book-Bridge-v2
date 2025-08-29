package com.devakash.bookbridge.pdfProcess;

import android.graphics.pdf.PdfDocument;

import com.devakash.bookbridge.pdfProcess.utils.CommonProgressData;
import com.devakash.bookbridge.pdfProcess.utils.DetailedDataOFprocessedPDF;
import com.devakash.bookbridge.pdfProcess.utils.PageOperationOutcome;
import com.devakash.bookbridge.pdfProcess.utils.PdfPageBundleInfo;
import com.devakash.bookbridge.pdfProcess.utils.commonPageBundlerHealper;
import com.tom_roush.pdfbox.io.MemoryUsageSetting;
import com.tom_roush.pdfbox.pdmodel.PDDocument;
import com.tom_roush.pdfbox.pdmodel.PDPage;
import com.tom_roush.pdfbox.pdmodel.PDPageTree;
import com.tom_roush.pdfbox.text.PDFTextStripper;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.MethodChannel;

public class PDFservices {

	public static void splitPDFpagesToBundle(String path, MethodChannel.Result result) {
		ExecutorService executor = Executors.newSingleThreadExecutor();
		executor.submit(() -> {
			try {
				Runtime.getRuntime().gc();
				//boolean processResult = splitPDFpagesToBundleHelperSync(path);
				String res=PdfGlobalStore.SplitPdf( path , "/storage/emulated/0/Download/BookBridge");
				PdfGlobalStore.RunOnUiThread(()->{
					Map<String, Object> data = new HashMap<>(3);
					if(PdfGlobalStore.detailedDataOFprocessedPDF!=null){
						data.put("result", PdfGlobalStore.detailedDataOFprocessedPDF.getSuccesFullBundledUrl());
					}
					data.put("status", true);
					result.success(data);
				});
				// PDF processing logic here
			} catch (Exception e) {
				System.out.println(e);

			}catch (OutOfMemoryError e) {
				System.out.println(e);

			} finally {
				Runtime.getRuntime().gc();
				executor.shutdown();
				if(PdfGlobalStore.Methodresult != null){
					PdfGlobalStore.Methodresult.success(false);
				}

			}
		});
	}



	public static void combinePdfBundlesToSinglePdf(List<String> transulatedpath, MethodChannel.Result result) {


		ExecutorService executor = Executors.newSingleThreadExecutor();
		executor.submit(() -> {
			try {
				Runtime.getRuntime().gc();
				boolean processResult= combinePdfBundlesToSinglePdfHealperSync(transulatedpath);
				Map<String, Object> data = new HashMap<>(3);
				data.put("status", processResult);
				PdfGlobalStore.RunOnUiThread(()->{
//					data.put("result", PdfGlobalStore.detailedDataOFprocessedPDF.getSuccesFullBundledUrl());

					result.success(data);
				});
				// PDF processing logic here
			} catch (Exception e) {
				System.out.println(e);
			}catch (OutOfMemoryError e) {
				System.out.println(e);
			} finally {
				Runtime.getRuntime().gc();
				executor.shutdown();
				if(PdfGlobalStore.Methodresult != null){
					PdfGlobalStore.Methodresult.success(false);
				}

			}
		});
	}
	public  static  <ANY_TYPE> ANY_TYPE getIndexValue(List<ANY_TYPE> listData,int index) {
       if(listData!=null && index < listData.size()){
         return listData.get(index);
	   }
	   return  null;
	}

	public  static  <ANY_TYPE> boolean addValueToIndex(List<ANY_TYPE> listData,int index ,ANY_TYPE data) {
		if(listData!=null && index < listData.size()){
			listData.set(index,data);
			return true;
		}
		return  false;
	}

	public static PDDocument loadPdfFromCache(int index,List<String> transulatedpath, List<PDDocument> cacheOFLoadedPdf,List<Boolean> isTryLoadedPDF) {

		boolean result = Boolean.TRUE.equals(getIndexValue(isTryLoadedPDF, index)); // check is it is already loaded

		if(result){
			PDDocument cachedPdf = getIndexValue(cacheOFLoadedPdf,index);

			return cachedPdf;
		}else {
			String path = getIndexValue(transulatedpath,index);
			PDDocument document = null;
			if(path!=null){
				File file = new File(path);
				document = loadPdf(file);

			}
			cacheOFLoadedPdf.add(index,document);
			isTryLoadedPDF.add(index,true);
			return  document;
		}
	}
	public static boolean combinePdfBundlesToSinglePdfHealperSync(List<String> transulatedpath) {
		if(PdfGlobalStore.detailedDataOFprocessedPDF==null){
			return false;
		}
		DetailedDataOFprocessedPDF combinedetail = PdfGlobalStore.detailedDataOFprocessedPDF;
		CommonProgressData progress = new CommonProgressData(combinedetail.getEachPageinBundleInfo().size());
		progressCallbackToDart(progress.updateOtherPdfProgress(5), "Initializing pdf from given path");

		List<Boolean> isTryLoadedPDF = new ArrayList<>(Collections.nCopies(transulatedpath.size(), false));
		List<PDDocument> transulatedPdfCacheStorage =new ArrayList<>(transulatedpath.size());
		progressCallbackToDart(progress.updateOtherPdfProgress(10), "Initializing pdf from given path");
		PDDocument finalOutPut = new PDDocument();
		PDDocument failedPdfPages =null;
		boolean tryedToLoadFailedPage = false;
		progressCallbackToDart(progress.updateOtherPdfProgress(15), "Initializing pdf from given path");
		for (int i=0;i<combinedetail.getEachPageinBundleInfo().size();i++){

			PdfPageBundleInfo eachPage= combinedetail.getEachPageinBundleInfo().get(i);

			if(eachPage.isBundledORnot()){
				PDDocument transulatedPdf =loadPdfFromCache(eachPage.getBundleNumber(),transulatedpath,transulatedPdfCacheStorage,isTryLoadedPDF);
				PDPage result =getPage(transulatedPdf,eachPage.getPageNoInBundle());
				if(result!=null){
					finalOutPut.addPage(result);
				}
			}else{
				if(failedPdfPages!=null){
					PDPage result =getPage(failedPdfPages,eachPage.getPageNoInBundle());
					if(result!=null){

						finalOutPut.addPage(result);
					}
				}else if(!tryedToLoadFailedPage){

					if(combinedetail.getFailedALLPageInOneBundleUrl()!=null){
						File file = new File(combinedetail.getFailedALLPageInOneBundleUrl());
						failedPdfPages = loadPdf(file);
						PDPage result =getPage(failedPdfPages,eachPage.getPageNoInBundle());
						if(result!=null){

							finalOutPut.addPage(result);
						}
					}
					tryedToLoadFailedPage=true;
				}

			}
			progressCallbackToDart(progress.updatePdfProcessingProgress(i), "loop");
		}
		//loadPdfFromCache();
		progressCallbackToDart(progress.updateOtherPdfProgress(55), "Initializing pdf from given path");

		File file =  PdfGlobalStore.savePdfToDisk(finalOutPut,"Combined_"+"example.pdf");
		for (PDDocument cleanupPdfobject: transulatedPdfCacheStorage) {
			close(cleanupPdfobject);
		}
		progressCallbackToDart(progress.updateOtherPdfProgress(90), "Initializing pdf from given path");

		close(failedPdfPages);

		progressCallbackToDart(progress.updateOtherPdfProgress(100), "Initializing pdf from given path");
		return true;
	}

	public static boolean splitPDFpagesToBundleHelperSync(String path) {
		File file = new File(path);
        String dir = file.getParent();
		String fileName = file.getName();

		progressCallbackToDart(5, "Initializing pdf from given path");

		if(checkForCancel(null)) return false; //check for cancel signal,

		PDDocument document = loadPdf(file);

		if(checkForCancel(document)) return false; //check for cancel signal,

		if (document == null) {
			return false;
		}

		PDPageTree OriginalPages = document.getPages();

		CommonProgressData progress = new CommonProgressData(OriginalPages);// get all data and methods for progress

		int sliceNumber = 0;
		long currentSliceSize = 0;

		if(checkForCancel(document)) return false; //check for cancel signal,

		PdfGlobalStore.pdfCallbackToFlutter(progress.updateOtherPdfProgress(50), "LOOP NUMBER");


		/********
		 *  intalise the needed things for storing pdf datas
		 */

		commonPageBundlerHealper bundlerHealper =new commonPageBundlerHealper(fileName,OriginalPages.getCount());

//		PDDocument succesFullpagePdfBundle = newPDF();
//		short currentPDFBundleNo=0;
//		int succesfullyBundledPageNumber = -1;
		long bundledPdfTotalSize = 0;
//		List<String> SuccesFullBundledSavedLocation = new ArrayList<String>();
//		PDDocument failedPdfPageBundleObject = newPDF();
//		int failedBundledCurrPageNumber = -1;
//		 List<PdfPageBundleInfo> eachPageinBundleInfo = new ArrayList<PdfPageBundleInfo>();

		/********/


		for (int i = 0; i < progress.totalPdfPages; i++) {
			
			
			String type = PdfGlobalStore.getMessage();
		    System.out.println(PdfGlobalStore.getCurrentAbi());
			long startTime = System.nanoTime(); // More precise timing
System.out.println(PdfGlobalStore.pdfiumPath);
			PDPage originalPage = OriginalPages.get(i);
			if(checkForCancel(document)) return false; //check for cancel signal,

			PageOperationOutcome currentPageCommonInfo = commonOperationOnSinglePage(originalPage);

			if(!currentPageCommonInfo.isRedable  || currentPageCommonInfo.size > PdfGlobalStore.getPdfSplitSize()){

                bundlerHealper.addNewInValidPage(originalPage);

			} else  {

				if(( bundledPdfTotalSize + currentPageCommonInfo.size ) < PdfGlobalStore.getPdfSplitSize()
						&& bundlerHealper.getSuccessfulPageCount() < PdfGlobalStore.pdfSplitByPage){
                    bundledPdfTotalSize += currentPageCommonInfo.size;
					bundlerHealper.addNewValidPage(originalPage);
				}else {
					bundlerHealper.saveCurrentValidPdfBundle();
					bundledPdfTotalSize = currentPageCommonInfo.size;
					bundlerHealper.addNewValidPage(originalPage);
				}

			}


			PdfGlobalStore.pdfCallbackToFlutter(progress.updatePdfProcessingProgress(i), "LOOP NUMBER");
			long end = System.currentTimeMillis();
			long elapsedTime = (System.nanoTime() - startTime) / 1_000_000_000; // Convert to seconds

			if (elapsedTime >= 20) {// in second
				throw new RuntimeException("Potential memory issue: Page processing took longer than 20 seconds");
			}
		}

		PdfGlobalStore.pdfCallbackToFlutter(progress.updateOtherPdfProgress(75), "LOOP NUMBER");

		bundlerHealper.saveCurrentValidPdfBundle();

		PdfGlobalStore.pdfCallbackToFlutter(progress.updateOtherPdfProgress(85), "LOOP NUMBER");

		bundlerHealper.saveInValidPdfBundle();




		PdfGlobalStore.pdfCallbackToFlutter(progress.updateOtherPdfProgress(95), "LOOP NUMBER");

		if(checkForCancel(document)) return false; //check for cancel signal,

		PdfGlobalStore.pdfCallbackToFlutter(progress.updateOtherPdfProgress(100), "LOOP NUMBER");
		//int pageNumber = document.getNumberOfPages();
		close(document);
		PdfGlobalStore.detailedDataOFprocessedPDF = bundlerHealper.getFinalFullPDFDetail();
		return true;
	}




	public static PageOperationOutcome commonOperationOnSinglePage(PDPage originalPage) {
		PDDocument tempraryPdfObject = new PDDocument();
		tempraryPdfObject.addPage(originalPage);
		PageOperationOutcome res=new PageOperationOutcome(isTextPresent(tempraryPdfObject),getPdfSizeInMemory(tempraryPdfObject));
		return res;
	}


	public static long getPdfSizeInMemory(PDDocument document) {
		try (ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream()) {
			document.save(byteArrayOutputStream);
			return byteArrayOutputStream.size();
		} catch (Exception e) {
			return  0;
		}
	}



	public static boolean isTextPresent(PDDocument newDoc) {
		try {
			PDFTextStripper stripper = new PDFTextStripper();
			return containsSingleLetter(stripper.getText(newDoc));
		} catch (Exception e) {
			return  false;
		}
	}

	public static boolean containsSingleLetter(String str) {
		if(str==null) {
			return false;
		}
		int len = str.length();
		for (int i = 0; i < len; i++) {
			if (Character.isLetter(str.charAt(i))) {
				return true; // Found at least one letter
			}
		}
		return false;
	}

	public static PDDocument  loadPdf(File filePath){
		try {
			return PDDocument.load(filePath, MemoryUsageSetting.setupTempFileOnly());
		} catch (Exception e) {
			return null;
		}catch (OutOfMemoryError e) {
			return null;
		}

	}

	public static PDDocument  newPDF(){
			return new PDDocument();
	}

	public static void  savePdf(PDDocument pdfDocument,String name){
		savePdfToDisk(pdfDocument,name);
	}

	public static void  savePdf(PDDocument pdfDocument,String name,int totalPage){
		if(totalPage>-1){
			savePdfToDisk(pdfDocument,name);
		}

	}

	private static void close(PDDocument document){
		try {
			if(document!=null){
				document.close();
				System.out.println("closed document");
			}
			Runtime.getRuntime().gc();
			System.out.println("called gc");
		} catch (Exception e) {

		}
	}
	private static boolean checkForCancel(PDDocument document){
		boolean result = false;
		if(PdfGlobalStore.isRequestedForCancel){
			result=PdfGlobalStore.isRequestedForCancel;
			close(document);
			PdfGlobalStore.isRequestedForCancel=false;
			PdfGlobalStore.Methodresult.success(true);
		}
		return  result;
	}

	private  static void  progressCallbackToDart(int progress,String message){
		PdfGlobalStore.pdfCallbackToFlutter(progress, message);
	}

	private  static  boolean addPage(PDDocument document,PDPage originalPage){
		boolean res=false;

		try {
			if(document!=null){
				document.addPage(originalPage);
				res=true;
			}
		} catch (Exception e) {

		}
		return res;
	}

	private  static  PDPage getPage(PDDocument document,int index){
		PDPage res=null;

		try {
			if(document!=null){
				res=document.getPage(index);
			}
		} catch (Exception e) {

		}
		return res;
	}

	public static File savePdfToDisk(PDDocument pdfDocument,String name) {
		File file = null;
		try {
			// Get internal storage directory (Android Context required)
			File dir = new File("/storage/emulated/0/Download/","BookBridge");
			if (!dir.exists()) dir.mkdirs(); // Create folder if it doesn't exist

			// Define file location
			file = new File(dir, name);
			// Save PDF document
			pdfDocument.save(file);
			close(pdfDocument); // Close document after saving
			System.out.println("PDF saved at: " + file.getAbsolutePath());

		} catch (IOException e) {
			e.printStackTrace();
			file = null;
		}
		return  file;
	}

}
