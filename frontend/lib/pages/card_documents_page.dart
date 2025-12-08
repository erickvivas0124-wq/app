import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import '../widgets/custom_detail_bottom_bar.dart';
import '../widgets/custom_app_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../main.dart' as main_app;

class Document {
  final int id;
  final String title;
  final String fileName;
  final DateTime uploadedAt;
  final String fileUrl;

  Document({
    required this.id,
    required this.title,
    required this.fileName,
    required this.uploadedAt,
    required this.fileUrl,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    String fileUrl = json['file'] ?? json['file_url'] ?? json['fileUrl'] ?? '';
    String fileName = '';
    
    if (fileUrl.isNotEmpty) {
      fileName = fileUrl.split('/').last;
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }
    }
    
    if (fileName.isEmpty) {
      fileName = json['file_name'] ?? json['fileName'] ?? 'documento';
    }
    
    return Document(
      id: json['id'],
      title: json['title'],
      fileName: fileName,
      uploadedAt: DateTime.parse(json['uploaded_at'] ?? json['uploadedAt']),
      fileUrl: fileUrl,
    );
  }
}

class CardDocumentsScreen extends StatefulWidget {
  final String cardName;
  final int cardId;

  const CardDocumentsScreen({
    Key? key,
    required this.cardName,
    required this.cardId,
  }) : super(key: key);

  @override
  State<CardDocumentsScreen> createState() => _CardDocumentsScreenState();
}

class _CardDocumentsScreenState extends State<CardDocumentsScreen> {
  List<Document> documents = [];
  bool isLoading = false;
  
  static const String baseUrl = 'http://192.168.1.4:8000/'; 
  
  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

Future<void> _loadDocuments() async {
  setState(() {
    isLoading = true;
  });

  try {
    final client = http.Client();
    final response = await client.get(
      Uri.parse('$baseUrl/card/${widget.cardId}/documents/'),
      headers: {
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    print('Load documents response status: ${response.statusCode}');
    print('Load documents response body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> documentsJson = json.decode(response.body);
      setState(() {
        documents = documentsJson.map((doc) => Document.fromJson(doc)).toList();
      });
    } else {
      _showErrorMessage('Error al cargar documentos: ${response.statusCode}');
    }
  } catch (e) {
    print('Load documents error: $e');
    _showErrorMessage('Error de conexión: $e');
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

  Future<void> _uploadDocument(String title, File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/card/${widget.cardId}/documents/'),
      );

      request.fields['title'] = title;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessMessage('Documento subido exitosamente');
        _loadDocuments(); 
      } else {
        _showErrorMessage('Error al subir documento: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorMessage('Error al subir documento: $e');
    }
  }

  Future<void> _deleteDocument(int documentId) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/document/$documentId/delete/'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

      if (response.statusCode == 200 || response.statusCode == 204) {
      _showSuccessMessage('Documento eliminado exitosamente');
      _loadDocuments(); 
    } else {
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      _loadDocuments();
      
      _showErrorMessage('Documento posiblemente eliminado. Verificando...');
    }
  } catch (e) {
    _showErrorMessage('Error al eliminar documento: $e');
    _loadDocuments();
  }
}


Future<void> _downloadDocument(Document document) async {
  try {
    if (document.fileUrl.isEmpty) {
      _showErrorMessage('URL del archivo no disponible');
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Descargando archivo..."),
            ],
          ),
        );
      },
    );
    
    String downloadUrl = document.fileUrl;
    if (!downloadUrl.startsWith('http')) {
      downloadUrl = '$baseUrl${document.fileUrl}';
    }
    
    print('Downloading from: $downloadUrl');
    
    final response = await http.get(Uri.parse(downloadUrl));
    
    Navigator.of(context).pop();
    
    if (response.statusCode == 200) {
      String fileName = document.fileName;
      if (fileName.isEmpty || fileName == 'documento') {
        String contentType = response.headers['content-type'] ?? '';
        String extension = _getExtensionFromContentType(contentType);
        fileName = 'documento_${document.id}$extension';
      }
      
      fileName = fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      
      await _saveFileWithModernPermissions(response.bodyBytes, fileName, document.title);
      
    } else {
      _showErrorMessage('Error al descargar documento: ${response.statusCode}');
    }
  } catch (e) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    print('Download error: $e');
    _showErrorMessage('Error al descargar documento: $e');
  }
}

Future<void> _saveFileWithModernPermissions(List<int> bytes, String fileName, String title) async {
  try {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      print('Android SDK version: $sdkInt');
      
      if (sdkInt >= 30) {
        await _saveFileWithScopedStorage(bytes, fileName, title);
      } else if (sdkInt >= 23) {
        await _saveFileWithTraditionalPermissions(bytes, fileName, title);
      } else {
        await _saveFileToDownloads(bytes, fileName, title);
      }
    } else if (Platform.isIOS) {
      await _saveFileIOS(bytes, fileName, title);
    } else {
      await _saveFileGeneric(bytes, fileName, title);
    }
  } catch (e) {
    print('Error in _saveFileWithModernPermissions: $e');
    await _saveFileGeneric(bytes, fileName, title);
  }
}

Future<void> _saveFileWithScopedStorage(List<int> bytes, String fileName, String title) async {
  try {
  
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    _showSuccessMessage('Archivo guardado: $fileName');
    _showScopedStorageDialog(filePath, title, fileName);
    
  } catch (e) {
    print('Error in scoped storage: $e');
    await _saveFileGeneric(bytes, fileName, title);
  }
}

Future<void> _saveFileWithTraditionalPermissions(List<int> bytes, String fileName, String title) async {
  try {
    bool hasPermission = await _requestStoragePermission();
    
    if (hasPermission) {
      await _saveFileToDownloads(bytes, fileName, title);
    } else {
      _showErrorMessage('Permisos denegados. Guardando en carpeta de la aplicación...');
      await _saveFileGeneric(bytes, fileName, title);
    }
  } catch (e) {
    print('Error with traditional permissions: $e');
    await _saveFileGeneric(bytes, fileName, title);
  }
}

Future<bool> _requestStoragePermission() async {
  try {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 30) {
        var manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          bool shouldRequest = await _showPermissionDialog();
          if (shouldRequest) {
            manageStatus = await Permission.manageExternalStorage.request();
          }
        }
        return manageStatus.isGranted;
      } else {
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          bool shouldRequest = await _showPermissionDialog();
          if (shouldRequest) {
            storageStatus = await Permission.storage.request();
          }
        }
        return storageStatus.isGranted;
      }
    }
    return true; 
  } catch (e) {
    print('Error requesting permissions: $e');
    return false;
  }
}

Future<bool> _showPermissionDialog() async {
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Permisos necesarios'),
        content: const Text(
          'Para descargar archivos a tu dispositivo, necesitamos acceso al almacenamiento. '
          'Esto nos permitirá guardar el archivo en tu carpeta de Descargas.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Permitir'),
          ),
        ],
      );
    },
  ) ?? false;
}

Future<void> _saveFileToDownloads(List<int> bytes, String fileName, String title) async {
  try {
    Directory? downloadsDir;
    
    final possiblePaths = [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
      '/storage/Download',
    ];
    
    for (String path in possiblePaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        downloadsDir = dir;
        break;
      }
    }
    
    if (downloadsDir == null) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        downloadsDir = Directory('${externalDir.path}/Download');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
      }
    }
    
    if (downloadsDir != null) {
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      _showSuccessMessage('Archivo descargado en: Descargas/$fileName');
      _showFileActionDialog(filePath, title);
    } else {
      throw Exception('No se pudo acceder a la carpeta de descargas');
    }
  } catch (e) {
    print('Error saving to downloads: $e');
    await _saveFileGeneric(bytes, fileName, title);
  }
}

void _showScopedStorageDialog(String filePath, String title, String fileName) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Archivo guardado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('El archivo "$title" se ha guardado exitosamente.'),
            const SizedBox(height: 10),
            const Text(
              'Nota: En Android 11+, el archivo se guarda en la carpeta de la aplicación. '
              'Puedes compartirlo o abrirlo desde aquí.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Share.shareFiles([filePath], text: title);
              } catch (e) {
                print('Error sharing file: $e');
                _showErrorMessage('Error al compartir archivo');
              }
            },
            child: const Text('Compartir'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final result = await OpenFilex.open(filePath);
                if (result.type != ResultType.done) {
                  _showErrorMessage('No se pudo abrir el archivo');
                }
              } catch (e) {
                print('Error opening file: $e');
                _showErrorMessage('Error al abrir archivo');
              }
            },
            child: const Text('Abrir'),
          ),
        ],
      );
    },
  );
}
String _getExtensionFromContentType(String contentType) {
  switch (contentType.toLowerCase()) {
    case 'application/pdf':
      return '.pdf';
    case 'image/jpeg':
    case 'image/jpg':
      return '.jpg';
    case 'image/png':
      return '.png';
    case 'application/msword':
      return '.doc';
    case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      return '.docx';
    case 'application/vnd.ms-excel':
      return '.xls';
    case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      return '.xlsx';
    case 'text/plain':
      return '.txt';
    default:
      return '.pdf'; 
  }
}

Future<void> _saveFileAndroid(List<int> bytes, String fileName, String title) async {
  try {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        _showErrorMessage('Permisos de almacenamiento denegados');
        return;
      }
    }
    
    Directory? downloadsDir;
    
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    }
    
    if (downloadsDir != null) {
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      _showSuccessMessage('Archivo descargado en: Descargas/$fileName');
      
      _showFileActionDialog(filePath, title);
    } else {
      await _saveFileGeneric(bytes, fileName, title);
    }
  } catch (e) {
    print('Error saving file on Android: $e');
    await _saveFileGeneric(bytes, fileName, title);
  }
}

Future<void> _saveFileIOS(List<int> bytes, String fileName, String title) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    _showSuccessMessage('Archivo guardado: $fileName');
    
    _showFileActionDialog(filePath, title);
  } catch (e) {
    print('Error saving file on iOS: $e');
    _showErrorMessage('Error al guardar archivo: $e');
  }
}

Future<void> _saveFileGeneric(List<int> bytes, String fileName, String title) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    _showSuccessMessage('Archivo guardado: $fileName');
    _showFileActionDialog(filePath, title);
  } catch (e) {
    print('Error saving file: $e');
    _showErrorMessage('Error al guardar archivo: $e');
  }
}

void _showFileActionDialog(String filePath, String title) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Archivo descargado'),
        content: Text('¿Qué deseas hacer con "$title"?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await Share.shareFiles([filePath], text: title);
              } catch (e) {
                print('Error sharing file: $e');
                _showErrorMessage('Error al compartir archivo');
              }
            },
            child: const Text('Compartir'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final result = await OpenFilex.open(filePath);
                if (result.type != ResultType.done) {
                  _showErrorMessage('No se pudo abrir el archivo');
                }
              } catch (e) {
                print('Error opening file: $e');
                _showErrorMessage('Error al abrir archivo');
              }
            },
            child: const Text('Abrir'),
          ),
        ],
      );
    },
  );
}

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
         appBar: CustomAppBar(
        pageTitle: 'Documentos',
        showBackButton: true,
        onBackPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => main_app.CardDetailPage(cardId: widget.cardId),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadDocuments,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : documents.isEmpty
                  ? const Center(
                      child: Text(
                        "No encontramos ningún documento.\nDesliza hacia abajo para actualizar",
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final document = documents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        document.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.download, color: Colors.blue),
                                          onPressed: () {
                                            _downloadDocument(document);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () {
                                            _showDeleteConfirmationDialog(document);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Text(
                                  "Fecha de carga: ${DateFormat('dd MMM yyyy, HH:mm').format(document.uploadedAt)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Archivo: ${document.fileName}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddDocumentDialog();
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: CustomDetailBottomBar(
        cardId: widget.cardId,
        currentPage: '/card_documents/${widget.cardId}',
      ),
    );
  }

  void _showAddDocumentDialog() {
    String title = '';
    File? selectedFile;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Agregar Documento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        title = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles();
                        
                        if (result != null) {
                          selectedFile = File(result.files.single.path!);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Archivo seleccionado: ${result.files.single.name}')),
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_file),
                          const SizedBox(width: 8),
                          Text(selectedFile != null ? 'Archivo seleccionado' : 'Seleccionar Archivo'),
                        ],
                      ),
                    ),
                    if (selectedFile != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Archivo: ${selectedFile!.path.split('/').last}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (title.isNotEmpty && selectedFile != null) {
                      Navigator.of(context).pop();
                      _uploadDocument(title, selectedFile!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor ingrese un título y seleccione un archivo')),
                      );
                    }
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Document document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que deseas eliminar el documento "${document.title}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteDocument(document.id);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }
}