import 'dart:async';
import 'dart:io';
import 'package:book_bridge/pdfService/utils/actions_builder.dart';
import 'package:book_bridge/pdfService/utils/file_detail.dart';
import 'package:book_bridge/pdfService/utils/pdf_reuploded_healper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;

void main() async {
  runApp(const BookBridge());
}

const List<Widget> hint = [
  SelectableText(
      "• In your command, use the key @f_ to automatically replace it with the selected file's URL. \nexample:\n     (@f_ => '/0/download/input.mp4')\n"),
  SelectableText(
      "• For the output location, use the key @s_ to replace it with the download location '/0/download/' on your Android device. \nexample:\n     (@s_output.mp4 => '/0/download/output.mp4')\n"),
  SelectableText(
      "• Use the key @ext_ to replace it with the selected file’s extension. This helps in writing generic commands. \nexample:\n     (@s_output@ext_ => '/0/download/output.mp4')\n"),
  SelectableText(
      "• You can use @s_ to access additional files from the download folder, which can be useful for adding subtitles or audio to a video file.\n"),
  SelectableText(
      "• To keep this process running in the background, go to **Settings > Battery > Battery Optimization**, find this app, and select **Don't optimize**. This prevents the system from stopping the process when the app is not in use."),
];

String dirPath = "/storage/emulated/0/Download/bookBridge/currentSliced/";

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
    // Get Android version
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    int sdkInt = androidInfo.version.sdkInt; // SDK version as an integer

    if (sdkInt >= 30) {
      // Android 11 (SDK 30) or higher
      if (await Permission.manageExternalStorage.isGranted) {
        print("Manage External Storage permission already granted.");
        return true;
      } else {
        var status = await Permission.manageExternalStorage.request();
        if (status.isGranted) {
          print("Manage External Storage permission granted.");
          return true;
        } else {
          await openAppSettings();
          return false;
        }
      }
    } else {
      // For Android versions lower than 11
      if (await Permission.storage.isGranted) {
        print("Storage permission already granted.");
        return true;
      } else {
        var storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          print("Storage permission granted.");
          return true;
        } else {
          print("Storage permission denied.");
          return false;
        }
      }
    }
  } else {
    // For non-Android platforms
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
      const MethodChannel('com.devakash.book_bridge/initalize');
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

    Directory dir = Directory(dirPath);
    if (!dir.existsSync()) {
      print("Directory does not exist. Creating it...");
      dir.createSync(recursive: true); // Creates the directory
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == "pdfCallback") {
        Map<dynamic, dynamic> data = call.arguments;
        int progress = data["progress"];
        String status = data["status"];

        print("Progress: $progress, Status: $status");
      }
    });
    //create a new thread and make that alive so that we can run pdf operation side by side AND Not freez UI
    // createNewThread();
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
      pdfUploadList.forEach((data) {
        uploadFiLeUrl.add(data.transulatedPdfUrl!);
      });
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
        title: const Text(
          "Book Bridge",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // secondThread?.send("Hello from main!");
                      },
                      icon: const Icon(Icons.notes),
                      label: const Text("Command Center"),
                    ),
                  ),
                  const SizedBox(width: 8), // Adds spacing between buttons
                  Expanded(
                    child: SwipeButton(
                      actions: actions,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const ExpandableContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: hint,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Progress Bar & Status
                  if (isConverting)
                    Column(
                      children: [
                        LinearProgressIndicator(value: progress / 100),
                        const SizedBox(height: 8),
                        Text("Progress: $progress%"),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // Buttons & Switch in a Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Start Conversion / Cancel Button
                      Expanded(
                        child: ElevatedButton.icon(
                          // onPressed:
                          //     isConverting ? cancelConversion : startConversion,
                          onPressed: isConverting
                              ? cancelPdfProcess
                              : processSelectedPdf,
                          icon: const Icon(Icons.play_circle),
                          label: isConverting
                              ? const Text("Cancel")
                              : const Text("Bundle pdf"),
                        ),
                      ),
                      const SizedBox(
                          width: 12), // Adds spacing between elements

                      // Events/File Switch (Ensures Text & Switch stay together)
                      Flexible(
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.end, // Aligns to the right
                          children: [
                            const Text("Event / File"),
                            const SizedBox(width: 2),
                            Switch(
                              value: isSwitched,
                              activeTrackColor: Colors.blue[100],
                              activeColor: Colors.blue,
                              inactiveThumbColor: Colors.green,
                              onChanged: (value) {
                                setState(() {
                                  isSwitched = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ), // Red-colored log area
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _isError
                          ? const Color(0xFFD32F2F)
                          : Colors.blue.shade700,
                      width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        isSwitched
                            ? "File Information"
                            : "Current Event Information",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign
                            .center, // Ensures text alignment inside the widget
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Limit the height of the scrollable view
                    SizedBox(
                      height: heightOfTxt,
                      // Adjust the height as needed
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.vertical,
                        child: Text(
                          isSwitched ? SelectedFileInfo : logOutput.toString(),
                          style: TextStyle(
                            fontFamily: "monospace",
                            fontWeight: FontWeight
                                .w500, // Medium weight for balanced emphasis
                            height:
                                1.4, // Slightly more spacing for multi-line readability
                            fontSize: 14, // Optimal for log display
                            letterSpacing: 0.5,
                            color: _isError
                                ? Colors.red.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (pdfUploadList.isNotEmpty)
                SizedBox(
                  height: 250,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        "Upload PDFs",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: pdfUploadList.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            print(pdfUploadList[index].transulatedPdfUrl);
                            print("okkk");
                            return Card(
                              elevation: 5,
                              color: Colors.blue.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '(${index + 1}) ${pdfUploadList[index].originalPath}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      showCustomFilePicker(
                                        context,
                                        (path) {
                                          setState(() {
                                            if (!pdfUploadList[index]
                                                .isReUploaded) {
                                              uploadedPdfNumber++;
                                            }

                                            pdfUploadList[index].isReUploaded =
                                                true;
                                            pdfUploadList[index]
                                                .transulatedPdfUrl = path;
                                          });
                                        },
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                    ),
                                    child: Text(
                                        pdfUploadList[index].isReUploaded
                                            ? "uploaded"
                                            : "Upload"),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                // onPressed:
                                //     isConverting ? cancelConversion : startConversion,
                                onPressed: () {
                                  setState(() {
                                    pdfUploadList = [];
                                    uploadedPdfNumber = 0;
                                    logOutput.clear();
                                    isConverting = false;
                                    progress = 0.0;
                                  });
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text("Cancel Merge"),
                              ),
                            ),
                            const SizedBox(width: 20),
                            if (uploadedPdfNumber > 0 &&
                                uploadedPdfNumber == pdfUploadList.length)
                              Expanded(
                                child: ElevatedButton.icon(
                                  // onPressed:
                                  //     isConverting ? cancelConversion : startConversion,
                                  onPressed: () {
                                    combinePdf();
                                  }, // Disables the button when condition is not met
                                  icon: const Icon(Icons.play_circle),
                                  label: const Text("Merge"),
                                ),
                              ),

                            // ElevatedButton(
                            //   onPressed: () {
                            //     // Cancel action logic
                            //     //cancelCombine();
                            //   },
                            //   style: ElevatedButton.styleFrom(
                            //     backgroundColor: Colors.red.shade500,
                            //     foregroundColor: Colors.white,
                            //     padding: const EdgeInsets.symmetric(
                            //         horizontal: 40, vertical: 16),
                            //   ),
                            //   child: const Text(
                            //     "Cancel Combine",
                            //     style: TextStyle(
                            //         fontSize: 12, fontWeight: FontWeight.bold),
                            //   ),
                            // ),
                            // Space between buttons
                            // ElevatedButton(
                            //   onPressed: (uploadedPdfNumber > 0 &&
                            //           uploadedPdfNumber == pdfUploadList.length)
                            //       ? () {
                            //           combinePdf();
                            //         }
                            //       : null, // Disables the button when condition is not met
                            //   style: ElevatedButton.styleFrom(
                            //     backgroundColor: Colors.blue.shade500,
                            //     foregroundColor: Colors.white,
                            //     padding: const EdgeInsets.symmetric(
                            //         horizontal: 50, vertical: 16),
                            //   ),
                            //   child: const Text(
                            //     "Combine",
                            //     style: TextStyle(
                            //         fontSize: 12, fontWeight: FontWeight.bold),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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

//---------
class ExpandableContainer extends StatefulWidget {
  final Widget child;

  const ExpandableContainer({super.key, required this.child});

  @override
  _ExpandableContainerState createState() => _ExpandableContainerState();
}

class _ExpandableContainerState extends State<ExpandableContainer>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100], // Background color
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade900),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Show Hints",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.blue.shade800,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastLinearToSlowEaseIn,
          child: isExpanded
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50], // Slightly lighter shade
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.child, // Static text or any content
                )
              : const SizedBox(), // Takes no space when collapsed
        ),
      ],
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
