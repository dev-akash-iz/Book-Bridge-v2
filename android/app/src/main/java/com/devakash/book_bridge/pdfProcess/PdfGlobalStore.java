package com.devakash.book_bridge.pdfProcess;

import android.os.Handler;
import android.os.Looper;

import com.devakash.book_bridge.pdfProcess.utils.DetailedDataOFprocessedPDF;
import com.tom_roush.pdfbox.pdmodel.PDDocument;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class PdfGlobalStore {
	public static  volatile String pdfProcessName="";
	private static  volatile boolean anyPdfProcessing=false;
//	private static volatile PDDocument document;
	private static volatile long pdfSplitBySize= 9*1024*1024;


	public static  volatile DetailedDataOFprocessedPDF detailedDataOFprocessedPDF=null;
	public static  volatile long pdfSplitByPage= 298;
	private static  volatile  MethodChannel methodChannel=null;
	public static  volatile boolean isRequestedForCancel=false;
	public static  volatile MethodChannel.Result Methodresult=null;

	public static volatile  EventChannel.EventSink eventSink;

	private static  volatile ExecutorService executor;

	private static final Handler mainThreadHandler = new Handler(Looper.getMainLooper());

	public static void setMethodChannel(MethodChannel methodChannel) {
		PdfGlobalStore.methodChannel = methodChannel;
		executor = Executors.newSingleThreadExecutor();
	}

	public static ExecutorService getOptimalExecutor() {
		int coreCount = Runtime.getRuntime().availableProcessors(); // Get CPU core count
		return Executors.newFixedThreadPool(coreCount); // Thread pool size = CPU cores
	}

	public static MethodChannel getMethodChannel() {
		return methodChannel;
	}

	public static String getPdfProcessName() {
		return pdfProcessName;
	}

	public static boolean isAnyPdfProcessing() {
		return anyPdfProcessing;
	}

//	public static PDDocument getDocument() {
//		return document;
//	}

	public static long getPdfSplitSize() {
		return pdfSplitBySize;
	}

	public static void updateProcessState(Boolean status) {
		PdfGlobalStore.anyPdfProcessing=status;
	}

//	public static void setCurrentLoadedDocument(PDDocument document) {
//		PdfGlobalStore.document = document;
//	}

	public static void clearCurrentLoadedPdf(){
		if(detailedDataOFprocessedPDF!=null){
			detailedDataOFprocessedPDF.clear();
		}
		isRequestedForCancel=false;
	}

	public static void pdfCallbackToFlutter(int progress, String Status) {
		Map<String, Object> data = new HashMap<>(3);
		data.put("progress", progress);
		data.put("status", Status);
		//Push the runnable to the main thread’s message queue and wait for the main thread to pick it up and execute it


		if (eventSink != null) {
			//mainThreadHandler.removeCallbacksAndMessages(null);
			mainThreadHandler.post(()->{
				PdfGlobalStore.eventSink.success(data);
			});
		}
	}

	public static void RunOnUiThread(Runnable runnableFunciton){
		if(runnableFunciton!=null){
			mainThreadHandler.post(runnableFunciton);
		}

	}

	public static File savePdfToDisk(PDDocument pdfDocument, String name) {
		File file = null;
		boolean isSaved=false;
		try {
			// Get internal storage directory (Android Context required)
			File dir = new File("/storage/emulated/0/Download/","BookBridge");
			if (!dir.exists()) dir.mkdirs(); // Create folder if it doesn't exist

			// Define file location
			file = new File(dir, name);
			// Save PDF document
			pdfDocument.save(file);
			isSaved=true;
			close(pdfDocument); // Close document after saving
			System.out.println("PDF saved at: " + file.getAbsolutePath());

		} catch (IOException e) {

			if(!isSaved){
				file = null;
			}
			e.printStackTrace();
		}
		return  file;
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


}
