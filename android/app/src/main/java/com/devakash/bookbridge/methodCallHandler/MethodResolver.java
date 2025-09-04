package com.devakash.bookbridge.methodCallHandler;

import androidx.annotation.NonNull;

import com.devakash.bookbridge.pdfProcess.PDFservices;
import com.devakash.bookbridge.pdfProcess.PdfGlobalStore;
import com.tom_roush.pdfbox.pdmodel.PDDocument;

import java.util.List;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MethodResolver implements MethodChannel.MethodCallHandler {

    private MethodChannel methodChannel=null;

	public MethodResolver(MethodChannel methodChannel) {
		this.methodChannel=methodChannel;
	}

	@Override
	public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {

		switch (call.method) {
			case "processPdf":
               
			    System.out.println(PdfGlobalStore.getAppPrivateDir("BookBridge"));
				PdfGlobalStore.clearCurrentLoadedPdf(); 
				PDFservices.splitPDFpagesToBundle((String) call.arguments,result);
				break;
			case "isRequestedForCancel":
                
				//PdfGlobalStore.CancelNative();
				PdfGlobalStore.isRequestedForCancel=true;
				PdfGlobalStore.Methodresult = result;
				break;
			case "combinePdf":

				if(PdfGlobalStore.detailedDataOFprocessedPDF==null){
					result.success(false);
				}else {
					PDFservices.combinePdfBundlesToSinglePdf((List<String>) call.arguments,result);
					//result.success(true);
				}
				PdfGlobalStore.Methodresult = result;
				break;
			default:
				result.notImplemented();
				break;
		}
	}
}
