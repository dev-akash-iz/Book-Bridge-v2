package com.devakash.book_bridge.pdfProcess;

import com.devakash.book_bridge.pdfProcess.utils.CommonProgressData;
import com.devakash.book_bridge.pdfProcess.utils.PageOperationOutcome;
import com.tom_roush.pdfbox.io.MemoryUsageSetting;
import com.tom_roush.pdfbox.pdmodel.PDDocument;
import com.tom_roush.pdfbox.pdmodel.PDPage;
import com.tom_roush.pdfbox.pdmodel.PDPageTree;
import com.tom_roush.pdfbox.text.PDFTextStripper;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.MethodChannel;

public class PDFservices {

	public static void splitPDFpagesToBundle(String path, MethodChannel.Result result) {
		ExecutorService executor = Executors.newSingleThreadExecutor();
		executor.submit(() -> {
			try {
				Runtime.getRuntime().gc();
				boolean processResult=splitPDFpagesToBundleHelperSync(path);
				PdfGlobalStore.RunOnUiThread(()->{
						result.success(processResult);
				});
				// PDF processing logic here
			} catch (Exception e) {
				System.out.println(e);
				System.out.println("other way errro");
			}catch (OutOfMemoryError e) {
				System.out.println(e);
				System.out.println("out of meansoryyyyy");
			} finally {
				Runtime.getRuntime().gc();
				executor.shutdown();
				if(PdfGlobalStore.Methodresult != null){
					PdfGlobalStore.Methodresult.success(false);
				}

			}
		});
	}

	public static boolean splitPDFpagesToBundleHelperSync(String path) {
		progressCallbackToDart(5, "LOOP NUMBER");

		if(checkForCancel(null)) return false;

		PDDocument document = loadPdf(path);

		if(checkForCancel(document)) return false;

		if (document == null) {
			return false;
		}

		PDPageTree OriginalPages = document.getPages();

		CommonProgressData progress = new CommonProgressData(OriginalPages);// get all data and methods for progress

		int sliceNumber = 0;
		long currentSliceSize = 0;

		if(checkForCancel(document)) return false;


		PdfGlobalStore.pdfCallbackToFlutter(progress.updateOtherPdfProgress(50), "LOOP NUMBER");

		for (int i = 0; i < progress.totalPdfPages; i++) {
			long startTime = System.nanoTime(); // More precise timing

			if(checkForCancel(document)) return false;

			PDPage originalPage = OriginalPages.get(i);
			if(checkForCancel(document)) return false;

			PageOperationOutcome currentPageCommonInfo = commonOperationOnSinglePage(originalPage);

			if (currentPageCommonInfo.isRedable && currentPageCommonInfo.size < PdfGlobalStore.getPdfSplitSize()) {

			} else {
				//failed pdf store this object into so recreate
			}


			PdfGlobalStore.pdfCallbackToFlutter(progress.updatePdfProcessingProgress(i), "LOOP NUMBER");
			long end=System.currentTimeMillis();
			long elapsedTime = (System.nanoTime() - startTime) / 1_000_000_000; // Convert to seconds

			if (elapsedTime > 10) {
				throw new RuntimeException("Potential memory issue: Page processing took longer than 20 seconds");
			}
		}
		if(checkForCancel(document)) return false;

		PdfGlobalStore.pdfCallbackToFlutter(progress.updateOtherPdfProgress(100), "LOOP NUMBER");
		//int pageNumber = document.getNumberOfPages();
		close(document);
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

	public static PDDocument  loadPdf(String filePath){
		try {
			return PDDocument.load(new File(filePath), MemoryUsageSetting.setupTempFileOnly());
		} catch (Exception e) {
			return null;
		}catch (OutOfMemoryError e) {
			return null;
		}

	}

	public static PDDocument  newPDF(){
			return new PDDocument();
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

}
