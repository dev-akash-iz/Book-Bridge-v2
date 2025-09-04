import 'dart:async';
import 'dart:io';
import 'package:bookbridge/pdfService/utils/actions_builder.dart';
import 'package:bookbridge/pdfService/utils/file_detail.dart';
import 'package:bookbridge/pdfService/utils/pdf_reuploded_healper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;

void main() async {
  runApp(const BookBridge());
}

const List<Widget> hint = [
  SelectableText(""),
];

class BookBridge extends StatelessWidget {
  const BookBridge({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const BookBridgeHome(),
    );
  }
}

class BookBridgeHome extends StatefulWidget {
  const BookBridgeHome({super.key});

  @override
  _BookBridgeHomeState createState() => _BookBridgeHomeState();
}

Future<bool> requestStoragePermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    int sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      // ✅ Android 11 and above -> Manage External Storage
      if (await Permission.manageExternalStorage.isGranted) {
        print("Manage External Storage permission already granted.");
        return true;
      } else {
        var status = await Permission.manageExternalStorage.request();
        if (status.isGranted) {
          print("Manage External Storage permission granted.");
          return true;
        } else {
          print("Manage External Storage permission denied.");
          await openAppSettings();
          return false;
        }
      }
    } else {
      // ✅ Android 10 and below -> Read + Write
      bool readGranted = await Permission.storage.isGranted;
      bool writeGranted = await Permission.accessMediaLocation.isGranted;
      // Note: some devices also gate "write" behind media location on <29

      if (readGranted && writeGranted) {
        print("Read & Write permissions already granted.");
        return true;
      } else {
        var readStatus = await Permission.storage.request();
        var writeStatus = await Permission.accessMediaLocation.request();

        if (readStatus.isGranted && writeStatus.isGranted) {
          print("Read & Write permissions granted.");
          return true;
        } else {
          print("Read or Write permission denied.");
          return false;
        }
      }
    }
  } else {
    // Non-Android (iOS, Web, etc.)
    print("Storage permission not required on this platform.");
    return true;
  }
}

String bytesToSizeFormate(double totalBytes, [String? include = ""]) {
  String result;
  if (totalBytes >= 1024 * 1024 * 1024) {
    result = "${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  } else if (totalBytes >= 1024 * 1024) {
    result = "${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  } else if (totalBytes >= 1024) {
    result = "${(totalBytes / 1024).toStringAsFixed(2)} KB";
  } else {
    result = "${totalBytes.toStringAsFixed(2)} Unknown";
  }
  return '$result $include';
}

class _BookBridgeHomeState extends State<BookBridgeHome>
    with WidgetsBindingObserver {
  final MethodChannel _channel =
      const MethodChannel('com.devakash.bookbridge/initalize');
  StreamSubscription? _subscription;

  final ScrollController _scrollController = ScrollController();

  List<PdfReuplodedHealper> pdfUploadList = [];
  int uploadedPdfNumber = 0;

  static const String parentPath = '/storage/emulated/0/Download';
  double heightOfTxt = 120;
  double progress = 0.0;
  bool isConverting = false;
  bool isSwitched = false;
  String? selectedFilePath;
  StringBuffer logOutput = StringBuffer(
      'Currenet memeory usage ${bytesToSizeFormate(ProcessInfo.currentRss.toDouble())}\n Max memeory usage allowed ${bytesToSizeFormate(ProcessInfo.maxRss.toDouble())}');
  String SelectedFileInfo = '';
  final bool _isError = false;

  String sf = '@f_'; //selected file string
  String fsl = '@s_'; // file save location
  final String ffmpeg = 'ffmpeg'; // ffmpeg string
  final String ext = '@ext_'; // ffmpeg string

  String manualPath = '';
  late List<DropdownMenuItem<String>> dropdownItems;
  Map<String, String> settingsMap = {};
  String? currentPath;

  List<FileSystemEntity> items = [];
  List<dynamic> commandFromGlobal_variable = [];

  List<ActionBuilder>? actions = [];

  @override
  void initState() {
    super.initState();
    actions = [
      ActionBuilder("Select File", Icons.music_video, () {
        showCustomFilePicker(context);
      })
    ];

    _channel.setMethodCallHandler((call) async {
      if (call.method == "pdfCallback") {
        Map<dynamic, dynamic> data = call.arguments;
        int progress = data["progress"];
        String status = data["status"];

        print("Progress: $progress, Status: $status");
      }
    });
  }

  void _scrollToBottom() {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void bactonormal() {
    setState(() {
      heightOfTxt = 150;
    });
  }

  void cancelPdfProcess() {
    _channel
        .invokeMethod<bool>("isRequestedForCancel", selectedFilePath)
        .then((bool? result) {
      if (result != null && result) {}
      setState(() {
        pdfUploadList = [];
        uploadedPdfNumber = 0;
        logOutput.clear();
        isConverting = false;
        progress = 0.0;
      });
    });
  }

  void startListening() {
    _subscription = const EventChannel('com.example/event')
        .receiveBroadcastStream()
        .listen((data) {
      int prog = data["progress"];
      String status = data["status"];
      setState(() {
        logOutput.clear();
        logOutput.write('\n$status\n');
        logOutput.write(
            "\n\n Current memeory usage ${bytesToSizeFormate(ProcessInfo.currentRss.toDouble())}\n Max memeory usage allowed ${bytesToSizeFormate(ProcessInfo.maxRss.toDouble())}");
        progress = prog.toDouble();
        _scrollToBottom();
      });
      print("Received from Java: $data");
    });
  }

  void stopListening() {
    _subscription?.cancel(); // This triggers onCancel() in Android
    _subscription = null;
  }

  void showDialoge({String? message, String heading = "success"}) {
    if (message != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(heading, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  void setPdfPath(String path) {
    selectedFilePath = path;
    setState(() {
      logOutput.clear();
    });
  }

  void increaseHeight([int size = 300]) {
    int time = 500; // 7 seconds
    int frameRate = 30; // Target FPS
    int uiUpdatePerMilliSecond = (time / frameRate * 0.80).toInt();
    int currentHeight = 0;
    int incrementValuePerInterval = size ~/ frameRate;

    int startTime = DateTime.now().millisecondsSinceEpoch;

    Timer.periodic(Duration(milliseconds: uiUpdatePerMilliSecond), (timer) {
      print("Height: $heightOfTxt : $currentHeight ");
      int elapsedTime = DateTime.now().millisecondsSinceEpoch - startTime;

      if (currentHeight >= size) {
        timer.cancel(); // Stop when the height limit is reached
        return;
      }

      setState(() {
        currentHeight += incrementValuePerInterval;
        heightOfTxt += incrementValuePerInterval;
      });

      print("Height: $heightOfTxt (Elapsed: $elapsedTime ms)");
    });
  }

  void combinePdf() async {
    if (pdfUploadList.isNotEmpty) {
      List<String> uploadFiLeUrl = [];
      for (var data in pdfUploadList) {
        uploadFiLeUrl.add(data.transulatedPdfUrl!);
      }
      setState(() {
        //pdfUploadList = [];
        //uploadedPdfNumber = 0;
        logOutput.clear();
        isConverting = true;
      });
      startListening();
      _channel.invokeMethod("combinePdf", uploadFiLeUrl).then((data) {
        setState(() {
          bool status = data["status"] ?? false;
          showDialoge(
            message: status ? "combined succesfully" : "failed to combine",
            heading: status ? "Success" : "failed",
          );
          logOutput.clear();
          isConverting = false;
        });
      });
    } else {
      showDialoge(message: "Please upload to combine pdf");
    }
  }

  void processSelectedPdf() async {
    if (selectedFilePath != null) {
      setState(() {
        pdfUploadList = [];
        uploadedPdfNumber = 0;
        logOutput.clear();
        isConverting = true;
      });
      startListening();
      _channel.invokeMethod("processPdf", selectedFilePath).then((data) {
        setState(() {
          dynamic pdfLink = data["result"];
          pdfLink?.forEach((data) {
            pdfUploadList.add(PdfReuplodedHealper(originalPath: data));
          });

          print("check");
          bool status = data["status"] ?? false;
          isConverting = false;
          progress = 0.0;
          showDialoge(
            message: status
                ? "splited pdf for transulate ready"
                : "Canceled Successfully",
            heading: status ? "Success" : "Canceled",
          );
        });
      });
    } else {
      showDialoge(message: "Please select a pdf file");
    }
  }

  void showCustomFilePicker(BuildContext Parentcontext,
      [Function(String name)? callback]) async {
    var status = await requestStoragePermission();
    if (status) {
      showDialog(
        context: Parentcontext,
        barrierDismissible: false, // Prevent accidental closing
        builder: (contextPopup) {
          return CustomFilePicker(
              parentPath, callback ?? setPdfPath, contextPopup);
        },
      );
    }
  }

  @override
  void dispose() {
    // Perform cleanup
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Bridge"),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ---------- Step 1: Select File ----------
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.picture_as_pdf, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Step 1: Select PDF",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => showCustomFilePicker(context),
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Choose PDF"),
                    ),
                    if (selectedFilePath != null) ...[
                      const SizedBox(height: 8),
                      Text("Selected: $selectedFilePath",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87)),
                    ]
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// ---------- Step 2: Split PDF ----------
            if (selectedFilePath != null)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.call_split, color: Colors.blue),
                          SizedBox(width: 8),
                          Text("Step 2: Split PDF",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: isConverting
                            ? cancelPdfProcess
                            : processSelectedPdf,
                        icon: Icon(isConverting
                            ? Icons.cancel
                            : Icons.play_circle_fill),
                        label: Text(isConverting ? "Cancel" : "Split PDF"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isConverting ? Colors.red : Colors.blue,
                        ),
                      ),
                      if (isConverting) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: progress / 100),
                        const SizedBox(height: 6),
                        Text("Progress: ${progress.toStringAsFixed(0)}%"),
                      ]
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            /// ---------- Step 3: Upload Translated Parts ----------
            if (pdfUploadList.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.upload, color: Colors.orange),
                          SizedBox(width: 8),
                          Text("Step 3: Upload Translated PDFs",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pdfUploadList.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = pdfUploadList[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.picture_as_pdf,
                                color: item.isReUploaded
                                    ? Colors.green
                                    : Colors.grey),
                            title: Text("Part ${index + 1}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(item.originalPath ?? ""),
                            trailing: ElevatedButton(
                              onPressed: () {
                                showCustomFilePicker(context, (path) {
                                  setState(() {
                                    if (!item.isReUploaded) uploadedPdfNumber++;
                                    item.isReUploaded = true;
                                    item.transulatedPdfUrl = path;
                                  });
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: item.isReUploaded
                                    ? Colors.green
                                    : Colors.blue.shade700,
                              ),
                              child: Text(
                                  item.isReUploaded ? "Uploaded" : "Upload"),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            /// ---------- Step 4: Merge Back ----------
            if (uploadedPdfNumber > 0 &&
                uploadedPdfNumber == pdfUploadList.length)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.merge_type, color: Colors.green),
                          SizedBox(width: 8),
                          Text("Step 4: Merge Final PDF",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: combinePdf,
                        icon: const Icon(Icons.check_circle),
                        label: const Text("Merge PDFs"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            /// ---------- Event / File Logs ----------
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      value: isSwitched,
                      title: const Text("Event / File Info"),
                      onChanged: (value) => setState(() => isSwitched = value),
                    ),
                    const Divider(),
                    SizedBox(
                      height: 120,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Text(
                          isSwitched ? SelectedFileInfo : logOutput.toString(),
                          style: TextStyle(
                            fontFamily: "monospace",
                            fontSize: 14,
                            color: _isError ? Colors.red : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomFilePicker extends StatefulWidget {
  final String initialPath;
  final Function(String) updateParentMain;
  final BuildContext contextParent;

  void closeALL() {
    Navigator.pop(contextParent);
  }

  const CustomFilePicker(
      this.initialPath, this.updateParentMain, this.contextParent,
      {super.key});

  @override
  _CustomFilePickerState createState() => _CustomFilePickerState();
}

class _CustomFilePickerState extends State<CustomFilePicker> {
  final String topMostDirectory = '/storage/emulated/0';
  late String currentPath;
  Directory? currentdir;
  List<FileSystemEntity> items = [];
  List<FileDetails> files = [];
  bool filterFileExtension = true;
  bool activetedfilter = false;
  List<FileDetails> filteredFiles = [];
  TextEditingController searchController = TextEditingController();
  Map<String, bool> listExtension = {
    ".pdf": true,
  };

  @override
  void initState() {
    super.initState();
    currentPath = widget.initialPath;
    currentdir = Directory(currentPath);
    _loadFiles();
  }

  void _backNavigate() {
    if (topMostDirectory == currentPath) {
      widget.closeALL();
    } else {
      currentdir = Directory(path.dirname(currentPath));
      currentPath = currentdir!.path;
      setState(() {
        activetedfilter = false;
        filteredFiles = [];
        searchController.text = "";
        _loadFiles();
      });
    }
  }

  void _loadFiles() {
    if (currentdir!.existsSync()) {
      setState(() {
        items = currentdir!.listSync();
        files = [];
        for (var fileData in items) {
          FileDetails calculatedFileInfo = FileDetails(fileData.path);
          if (calculatedFileInfo.getExtensionIfValidElseNull() != null) {
            files.add(calculatedFileInfo);
          }
        }
      });
    }
  }

  void _navigateToFolder(String path) {
    currentdir = Directory(path);
    setState(() {
      activetedfilter = false;
      filteredFiles = [];
      searchController.text = "";
      currentPath = path;
      _loadFiles();
    });
  }

  void _selectFile(String filePath) {
    String fileExtension =
        filePath.substring(filePath.lastIndexOf("."), filePath.length);
    if (listExtension[fileExtension] == true) {
      widget.updateParentMain.call(filePath);
      widget.closeALL();
    } else {
      _showErrorDialog("Please select a valid Video/Audio file.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error", textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String folderName = path.basename(currentPath);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        title: Text(
          folderName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ), // Replace with your desired icon
            onPressed: () {
              widget.closeALL();
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            _backNavigate();
          }, // Close dialog
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: "Search files...",
                  prefixIcon: Icon(Icons.search, color: Colors.blueGrey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                ),
                onChanged: (query) {
                  setState(() {
                    activetedfilter = query.isNotEmpty;
                    filteredFiles = activetedfilter
                        ? files
                            .where((file) => file
                                .getFileNameInsmall()!
                                .contains(query.toLowerCase()))
                            .toList()
                        : [];
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: activetedfilter ? filteredFiles.length : files.length,
              itemBuilder: (context, index) {
                List<FileDetails> data =
                    activetedfilter ? filteredFiles : files;
                FileDetails fileInfo = data[index];

                return ListTile(
                  leading: Icon(
                      fileInfo.isFolder() ? Icons.folder : Icons.video_file),
                  title: Text(fileInfo.getFileName()!),
                  onTap: () {
                    if (fileInfo.isFolder()) {
                      _navigateToFolder(fileInfo.getPath());
                    } else {
                      _selectFile(fileInfo.getPath());
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SwipeButton extends StatefulWidget {
  final List<ActionBuilder>? actions;

  const SwipeButton({super.key, required this.actions});

  @override
  _SwipeButtonState createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton> {
  bool isSelectFile = true; // Tracks button state
  int currentButtonIndex = 0;
  int _actionLength = 0;
  bool _canSwipe = true;

  @override
  void initState() {
    super.initState();
    _actionLength = (widget.actions?.length ?? 0);
  }

  void _resetSwipe(DragEndDetails details) {
    setState(() {
      _canSwipe = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd:
          _resetSwipe, // reset on lift so again swipe to change another
      onVerticalDragUpdate: (details) {
        if (_canSwipe &&
            details.primaryDelta! < -6 &&
            (currentButtonIndex + 1) < _actionLength) {
          // logic is if it is swiped up and if

          setState(() {
            _canSwipe = false;
            ++currentButtonIndex;
          });
        } else if (_canSwipe &&
            details.primaryDelta! > 6 &&
            (currentButtonIndex - 1) > -1) {
          setState(() {
            _canSwipe = false;
            --currentButtonIndex;
          });
        }
      },
      child: ElevatedButton.icon(
        onPressed: () {
          widget.actions![currentButtonIndex].getOnSelectFun().call();
        },
        icon: Icon(widget.actions![currentButtonIndex].getIcon()),
        label: Text(widget.actions![currentButtonIndex].getName()),
      ),
    );
  }
}
