package com.devakash.book_bridge.pdfProcess.utils;

public class PdfPageBundleInfo {
	private Integer pageNoInBundle;
	private boolean bundledORnot;
	private int bundleNumber;

	public PdfPageBundleInfo(boolean bundledORnot,Integer pageNoInBundle, Integer bundleNumber ) {
		this.pageNoInBundle = pageNoInBundle;
		this.bundleNumber = bundleNumber;
		this.bundledORnot = bundledORnot;
	}

	public PdfPageBundleInfo(boolean bundledORnot, Integer pageNoInBundle) {
		this.bundledORnot = bundledORnot;
		this.pageNoInBundle = pageNoInBundle;
	}

	public int getPageNoInBundle() {
		return pageNoInBundle;
	}

	public boolean isBundledORnot() {
		return bundledORnot;
	}

	public int getBundleNumber() {
		return bundleNumber;
	}

	@Override
	public String toString() {
		return "PdfPageBundleInfo{" +
				"pageNoInBundle=" + pageNoInBundle +
				", bundledORnot=" + bundledORnot +
				", bundleNumber=" + bundleNumber +
				'}';
	}
}
