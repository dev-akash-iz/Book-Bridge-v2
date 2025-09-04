package com.devakash.bookbridge.pdfProcess;

import android.os.Handler;
import android.os.Looper;
import android.os.Build;
import com.devakash.bookbridge.pdfProcess.utils.DetailedDataOFprocessedPDF;
import com.tom_roush.pdfbox.pdmodel.PDDocument;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import android.content.Context;               
import java.text.SimpleDateFormat;
import java.util.Date;

import com.devakash.bookbridge.pdfProcess.utils.Location;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class PdfGlobalStore {
	public static  volatile String pdfProcessName="";
	private static  volatile boolean anyPdfProcessing=false;
//	private static volatile PDDocument document;
	private static volatile long pdfSplitBySize= 9*1024*1024;


	public static  volatile DetailedDataOFprocessedPDF detailedDataOFprocessedPDF=null;
	public static  volatile long pdfSplitByPage= 201;
	private static  volatile  MethodChannel methodChannel=null;
	public static  volatile boolean isRequestedForCancel=false;
	public static  volatile MethodChannel.Result Methodresult=null;

	public static volatile  EventChannel.EventSink eventSink;

	private static  volatile ExecutorService executor;

	private static final Handler mainThreadHandler = new Handler(Looper.getMainLooper());
    
    public static String pdfiumPath = "";
	public static Context CONTEXT = null;

	// Load the Rust shared library (without the "lib" prefix, without ".so")
	static {
		System.loadLibrary("untitled");
	}


	// Declare the native method
	public static native void hello();

	public static native String getMessage();

	public static native void loadPdfiumBinary(String path);

    /***
	 * this is native funtion to split -> rust lib -> c++ pdfium
	 */
	public static native String SplitPdf(String srcPath,String savePath);

	public static native boolean CancelNative();
	




	public static void intpdflib(Context context){
		System.out.println("loded pdfiumlib");
		CONTEXT = context;
        String libDir = context.getApplicationInfo().nativeLibraryDir;
		loadPdfiumBinary(pdfiumPath);
		pdfiumPath = libDir + "/libpdfium.so";
		System.out.println("loded pdfiumlib");
	}

	public static String getAppPrivateDir(String subDir) {
		File dir = CONTEXT.getExternalFilesDir(subDir);
		if (dir != null && !dir.exists()) {
			dir.mkdirs();
		}
		return (dir != null) ? dir.getAbsolutePath() : null;
	}

	public static void setMethodChannel(MethodChannel methodChannel) {
		PdfGlobalStore.methodChannel = methodChannel;
		executor = Executors.newSingleThreadExecutor();
		String type = getMessage();
		System.out.println(type);
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

	public static File savePdfToDisk(PDDocument pdfDocument,String location, String name) {
		File file = null;
		boolean isSaved=false;
		try {
			// Get internal storage directory (Android Context required)
			// File dir = new File("/storage/emulated/0/Download/BookBridge");
			// if (!dir.exists()) dir.mkdirs(); // Create folder if it doesn't exist

			// Define file location
			file = new File(location, name);
			// Save PDF document
			pdfDocument.save(file);
			isSaved = true;
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

	public static String  createFolderViaDate() {
		// yyyy-MM-dd for sortable date
		// hh-mm for 12-hour clock
		// a for AM/PM marker
		SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd__hh-mm_a");
		return sdf.format(new Date());
	}

	public static Location settingUpFolder(String path) {
		try {
			File file = new File(path);
			String fileName = file.getName();  // e.g. "document.pdf"

			// Remove extension safely
			int dotIndex = fileName.lastIndexOf('.');
			String nameWithoutExt = (dotIndex == -1) ? fileName : fileName.substring(0, dotIndex);

			Location loc = new Location();
			loc.sourceFile = file;
			loc.fileName = fileName;
			loc.fileNameWithoutExt = nameWithoutExt;

			// Root folder → e.g. /Download/bookBridge/document/2025-09-04__10-10_AM
			String dirPath = "/storage/emulated/0/Download/bookBridge/"
					+ loc.fileNameWithoutExt + "/" + createFolderViaDate();
			loc.rootFolder = dirPath;

			// Create root
			File dir = new File(loc.rootFolder);
			if (!dir.exists()) dir.mkdirs();

			// Create Failed folder
			loc.failed = loc.rootFolder + "/Failed";
			dir = new File(loc.failed);
			if (!dir.exists()) dir.mkdirs();

			// Create Splitted folder
			loc.splitted = loc.rootFolder + "/Splitted";
			dir = new File(loc.splitted);
			if (!dir.exists()) dir.mkdirs();

			// Create FinalTranslated folder (fixed from overwritten `splitted`)
			loc.finalTranslated = loc.rootFolder + "/FinalTranslated";
			dir = new File(loc.finalTranslated);
			if (!dir.exists()) dir.mkdirs();

			return loc;

		} catch (Exception e) {
			e.printStackTrace();
			return null;
		}
	}



     public static String getCurrentAbi() {
        // On modern Android this gives a list of supported ABIs, pick the first
        if (Build.SUPPORTED_ABIS != null && Build.SUPPORTED_ABIS.length > 0) {
            return Build.SUPPORTED_ABIS[0];  // e.g. "arm64-v8a"
        }
        // Fallback for old Android
        return Build.CPU_ABI; // e.g. "armeabi-v7a"
    }

}
