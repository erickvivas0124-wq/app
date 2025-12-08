import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api_service.dart' as api_service;
import '../widgets/custom_app_bar.dart';

class excelimport extends StatefulWidget {
  @override
  _ExcelImportState createState() => _ExcelImportState();
}

class _ExcelImportState extends State<excelimport> {
  File? selectedFile;
  bool isUploading = false;
  String? uploadMessage;
  bool isSuccess = false;
  List<String> errors = [];
  int createdCardsCount = 0;
  final storage = FlutterSecureStorage();

  Future<void> pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          selectedFile = File(result.files.single.path!);
          uploadMessage = null;
          errors.clear();
          isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        uploadMessage = 'Error al seleccionar archivo: $e';
        isSuccess = false;
      });
    }
  }

  Future<void> uploadExcelFile() async {
    if (selectedFile == null) {
      setState(() {
        uploadMessage = 'Por favor selecciona un archivo Excel';
        isSuccess = false;
      });
      return;
    }

    setState(() {
      isUploading = true;
      uploadMessage = null;
      errors.clear();
    });

    try {
      final csrfToken = await storage.read(key: 'csrftoken');
      final uri = Uri.parse('${api_service.ApiService.baseUrl}/import_cards_from_excel/');
      var request = http.MultipartRequest('POST', uri);

      request.headers['X-CSRFToken'] = csrfToken ?? '';

      request.files.add(
        await http.MultipartFile.fromPath('file', selectedFile!.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      Map<String, dynamic>? jsonResponse;
      try {
        jsonResponse = json.decode(responseData);
      } catch (e) {
        setState(() {
          isSuccess = false;
          uploadMessage = 'Error del servidor: $responseData';
        });
        return;
      }

      if (response.statusCode == 201) {
        setState(() {
          isSuccess = true;
          createdCardsCount = jsonResponse!['created_cards_count'] ?? 0;
          uploadMessage = 'Importación exitosa: $createdCardsCount tarjetas creadas';

          if (jsonResponse['errors'] != null && jsonResponse['errors'].isNotEmpty) {
            errors = List<String>.from(
              jsonResponse['errors'].map((error) =>
                'Fila ${error['row']}: ${error['error']}'
              )
            );
          }
        });
      } else {
        setState(() {
          isSuccess = false;
          uploadMessage = jsonResponse!['error'] ?? 'Error desconocido en la importación';
        });
      }
    } catch (e) {
      setState(() {
        isSuccess = false;
        uploadMessage = 'Error de conexión: $e';
      });
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  void clearSelection() {
    setState(() {
      selectedFile = null;
      uploadMessage = null;
      errors.clear();
      isSuccess = false;
      createdCardsCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        pageTitle: 'Importar desde Excel',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instrucciones para la importación',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Su archivo Excel debe contener las siguientes columnas (exactamente con estos nombres):',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    _buildRequiredColumn('nombre', 'Nombre del equipo'),
                    _buildRequiredColumn('marca', 'Marca del equipo'),
                    _buildRequiredColumn('modelo', 'Modelo del equipo'),
                    _buildRequiredColumn('serie', 'Número de serie'),
                    _buildRequiredColumn('clasificacion por riesgo', 'I, IIA, IIB, o III'),
                    _buildRequiredColumn('ubicacion', 'Área o ubicación del equipo'),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        border: Border.all(color: Colors.amber[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.amber[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Todas las tarjetas importadas tendrán estado "Activo" por defecto. Columnas adicionales serán ignoradas.',
                              style: TextStyle(color: Colors.amber[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleccionar archivo Excel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    if (selectedFile == null)
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: pickExcelFile,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 48,
                                color: Colors.grey[600],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Toca para seleccionar archivo Excel',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Formatos soportados: .xlsx, .xls',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.description, color: Colors.green[700]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Archivo seleccionado:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  Text(
                                    selectedFile!.path.split('/').last,
                                    style: TextStyle(color: Colors.green[600]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: clearSelection,
                            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedFile == null ? pickExcelFile : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Seleccionar archivo'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (selectedFile != null && !isUploading) 
                                ? uploadExcelFile 
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: isUploading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Importando...'),
                                    ],
                                  )
                                : Text('Importar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            if (uploadMessage != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSuccess ? Icons.check_circle : Icons.error,
                            color: isSuccess ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Resultado de la importación',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSuccess ? Colors.green[50] : Colors.red[50],
                          border: Border.all(
                            color: isSuccess ? Colors.green[300]! : Colors.red[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          uploadMessage!,
                          style: TextStyle(
                            color: isSuccess ? Colors.green[700] : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      if (errors.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text(
                          'Errores encontrados:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: errors.map((error) => 
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '• $error',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ).toList(),
                          ),
                        ),
                      ],
                      
                      if (isSuccess && createdCardsCount > 0) ...[
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/',
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 48),
                          ),
                          child: Text('Ver tarjetas importadas'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredColumn(String columnName, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '$columnName: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}