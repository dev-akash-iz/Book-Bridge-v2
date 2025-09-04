package com.devakash.bookbridge.pdfProcess.utils;

import android.graphics.pdf.PdfDocument;
import com.devakash.bookbridge.pdfProcess.utils.Location;
import java.util.List;

public class DetailedDataOFprocessedPDF {
	private List<String> SuccesFullBundledUrl;
	private String failedALLPageInOneBundleUrl;
	private String OriginalPdfUrl;
	private Location location;

	private List<PdfPageBundleInfo> eachPageinBundleInfo;

	public DetailedDataOFprocessedPDF(List<String> succesFullBundledUrl, String failedALLPageInOneBundleUrl, String originalPdfUrl, List<PdfPageBundleInfo> eachPageinBundleInfo) {
		SuccesFullBundledUrl = succesFullBundledUrl;
		this.failedALLPageInOneBundleUrl = failedALLPageInOneBundleUrl;
		OriginalPdfUrl = originalPdfUrl;
		this.eachPageinBundleInfo = eachPageinBundleInfo;
	}

	public DetailedDataOFprocessedPDF(List<String> succesFullBundledUrl, String failedALLPageInOneBundleUrl, String originalPdfUrl, List<PdfPageBundleInfo> eachPageinBundleInfo,Location location) {
		SuccesFullBundledUrl = succesFullBundledUrl;
		this.failedALLPageInOneBundleUrl = failedALLPageInOneBundleUrl;
		OriginalPdfUrl = originalPdfUrl;
		this.eachPageinBundleInfo = eachPageinBundleInfo;
		this.location = location;
	}

	public List<String> getSuccesFullBundledUrl() {
		return SuccesFullBundledUrl;
	}

	public String getFailedALLPageInOneBundleUrl() {
		return failedALLPageInOneBundleUrl;
	}

	public Location getLocation() {
		return this.location;
	}

	public String getOriginalPdfUrl() {
		return OriginalPdfUrl;
	}

	public List<PdfPageBundleInfo> getEachPageinBundleInfo() {
		return eachPageinBundleInfo;
	}

	public void clear(){
		this.failedALLPageInOneBundleUrl=null;
		this.eachPageinBundleInfo=null;
		this.OriginalPdfUrl=null;
		this.SuccesFullBundledUrl=null;
	}

}
