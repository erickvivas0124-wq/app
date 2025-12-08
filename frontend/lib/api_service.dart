import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/pages/maintenancepage.dart' as maintenance_page;



class Intervencion {
  final int id;
  final String actionType;
  final DateTime date;
  final String description;
  final String responsible;

  Intervencion({
    required this.id,
    required this.actionType,
    required this.date,
    required this.description,
    required this.responsible,
  });

  factory Intervencion.fromJson(Map<String, dynamic> json) {
    return Intervencion(
      id: json['id'],
      actionType: json['action_type'],
      date: DateTime.parse(json['date']),
      description: json['description'],
      responsible: json['responsible'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action_type': actionType,
      'date': date.toIso8601String().split('T')[0],
      'description': description,
      'responsible': responsible,
    };
  }
}

class ApiService {
  static const String baseUrl = 'http://192.168.1.4:8000';

  static Future<List<dynamic>> fetchCards() async {
    final client = http.Client();
    final response = await client.get(
      Uri.parse('$baseUrl/cards/'),
      headers: {
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load cards: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> fetchCardDetail(int cardId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/cards/$cardId/'),
      headers: {
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load card details: ${response.statusCode} - ${response.body}');
    }
  }


static Future<List<dynamic>> fetchDeletedCards() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cards/deleted/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData;
      } else {
        throw Exception('Failed to load deleted cards: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching deleted cards: $e');
    }
  }

  static Future<bool> softDeleteCard(int cardId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/cards/$cardId/soft_delete/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error deleting card: $e');
    }
  }

  static Future<bool> restoreCard(int cardId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/cards/$cardId/restore/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error restoring card: $e');
    }
  }

  static Future<bool> addCard(Map<String, dynamic> cardData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cards/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(cardData),
    );
    
    if (response.statusCode == 201) {
      return true;
    }
    return false;
  }

  static Future<List<dynamic>> fetchDocuments(int cardId) async {
    final response = await http.get(Uri.parse('$baseUrl/card/$cardId/documents/'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load documents: ${response.body}');
    }
  }

  static Future<bool> uploadDocument(int cardId, String title, File file) async {
    var uri = Uri.parse('$baseUrl/cards/$cardId/documents/upload/');
    var request = http.MultipartRequest('POST', uri);
    request.fields['title'] = title;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 201) {
      return true;
    }
    return false;
  }

  static Future<bool> deleteDocument(int documentId, {int? cardId, String? documentName}) async {
    final uri = Uri.parse('$baseUrl/document/$documentId/delete/');
    final response = await http.delete(uri);
    
    if (response.statusCode == 204) {
      return true;
    }
    return false;
  }

  static Future<Map<String, dynamic>> getMaintenanceData(int cardId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/card/$cardId/maintenance/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        
        List<maintenance_page.CronogramaEvento> cronogramas = [];
        List<Intervencion> intervenciones = [];
        
        if (data['cronogramas'] != null) {
          cronogramas = (data['cronogramas'] as List)
              .map((item) => maintenance_page.CronogramaEvento.fromJson({
                ...item,
                'card_id': item['card_id'] ?? cardId,
              }))
              .toList();
        }
        
        if (data['intervenciones'] != null) {
          intervenciones = (data['intervenciones'] as List)
              .map((item) => Intervencion.fromJson({
                ...item,
                'card_id': item['card_id'] ?? cardId,
              }))
              .toList();
        }
        
        return {
          'cronogramas': cronogramas,
          'intervenciones': intervenciones,
        };
      } else {
        throw Exception('Error al cargar datos de mantenimiento: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<maintenance_page.CronogramaEvento> createCronograma(int cardId, maintenance_page.CronogramaEvento cronograma) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/card/$cardId/cronograma/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(cronograma.toJson()),
      );

      if (response.statusCode == 201) {
        final createdCronograma = maintenance_page.CronogramaEvento.fromJson(json.decode(response.body));
        

        
        return createdCronograma;
      } else {
        try {
          Map<String, dynamic> errorData = json.decode(response.body);
          throw Exception('Error al crear cronograma: ${errorData['error'] ?? response.statusCode}');
        } catch (e) {
          throw Exception('Error al crear cronograma: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('Error al crear cronograma:')) {
        rethrow;
      }
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Intervencion> createIntervencion(int cardId, Intervencion intervencion) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/card/$cardId/intervencion/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(intervencion.toJson()),
      );

      if (response.statusCode == 201) {
        final createdIntervencion = Intervencion.fromJson(json.decode(response.body));


        return createdIntervencion;
      } else {
        try {
          Map<String, dynamic> errorData = json.decode(response.body);
          throw Exception('Error al crear intervención: ${errorData['error'] ?? response.statusCode}');
        } catch (e) {
          throw Exception('Error al crear intervención: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e.toString().contains('Error al crear intervención:')) {
        rethrow;
      }
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<List<int>> exportCardsToExcel() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/export_cards_to_excel/'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Error al exportar tarjetas: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al exportar tarjetas: $e');
    }
  }
}
