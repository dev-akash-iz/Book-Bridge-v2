package com.devakash.book_bridge.methodCallHandler;

import androidx.annotation.NonNull;

import com.devakash.book_bridge.pdfProcess.PDFservices;
import com.devakash.book_bridge.pdfProcess.PdfGlobalStore;
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
				System.out.println("");
				System.out.println("processPdf");
				System.out.println("");
				PdfGlobalStore.clearCurrentLoadedPdf();
				PDFservices.splitPDFpagesToBundle((String) call.arguments,result);
				break;
			case "isRequestedForCancel":
				System.out.println("");
				System.out.println("isRequestedForCancel");
				System.out.println("");
				PdfGlobalStore.isRequestedForCancel=true;
				PdfGlobalStore.Methodresult=result;
				break;
			case "combinePdf":
				System.out.println("");
				System.out.println("combinePdf");
				System.out.println("");
				if(PdfGlobalStore.detailedDataOFprocessedPDF==null){
					result.success(false);
				}else {
					PDFservices.combinePdfBundlesToSinglePdf((List<String>) call.arguments,result);
					//result.success(true);
				}
				PdfGlobalStore.Methodresult=result;
				break;
			default:
				result.notImplemented();
				break;
		}
	}
}
