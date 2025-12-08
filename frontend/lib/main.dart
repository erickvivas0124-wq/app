import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'api_service.dart' as api_service;
import 'widgets/custom_app_bar.dart';
import 'widgets/custom_detail_bottom_bar.dart';
import 'pages/card_documents_page.dart';
import 'pages/generalhistory.dart';
import 'pages/maintenancepage.dart' as maintenance_page; 
import 'pages/calendar_screen.dart';
import 'pages/import.dart';




final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
      navigatorObservers: [routeObserver],
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        if (uri.pathSegments.isEmpty) {
          return null;
        }
        if (uri.pathSegments[0] == 'card_documents' && uri.pathSegments.length == 2) {
          final cardId = int.tryParse(uri.pathSegments[1]);
          if (cardId != null) {
            return MaterialPageRoute(
builder: (context) => CardDocumentsScreen(cardId: cardId, cardName: 'Equipo $cardId'),
            );
          }
        }
        if (settings.name == '/generalhistory') {
          return MaterialPageRoute(
            builder: (context) => ManageCardsPage(),
          );
        }
        if (settings.name == '/calendar_screen') {
          return MaterialPageRoute(
            builder: (context) => CalendarScreen(),
          );
        }
        if (settings.name == '/import') {
          return MaterialPageRoute(
            builder: (context) => excelimport(),
          );
        }
        return null;
      },
    );
  }
}

class Card {
  final int id;
  final String name;
  final String status;
  final String model;
  final String brand;
  final String imageUrl;
  final String risk;
  final String location;

  Card({
    required this.id,
    required this.name,
    required this.status,
    required this.model,
    required this.brand,
    this.imageUrl = '',
    this.risk = '',
    this.location = '',
  });

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      id: json['id'],
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      model: json['model'] ?? '',
      brand: json['brand'] ?? '',
      imageUrl: json['image'] ?? '',
      risk: json['risk'] ?? '',
      location: json['location'] ?? '',
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Card> cards = [];
  List<Card> filteredCards = [];
  bool isFilterMenuVisible = false;

  Map<int, List<dynamic>> cardCronogramas = {};

  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameFilterController = TextEditingController();
  final TextEditingController modelFilterController = TextEditingController();
  final TextEditingController brandFilterController = TextEditingController();
  String statusFilter = '';

  final storage = FlutterSecureStorage();
  String? csrfToken;

  @override
  void initState() {
    super.initState();
    fetchCards();
    getCsrfToken();
  }

  Future<void> getCsrfToken() async {
  }

  Future<void> fetchCards() async {
    try {
      final List<dynamic> jsonData = await api_service.ApiService.fetchCards();
      setState(() {
        cards = jsonData.map((json) => Card.fromJson(json)).toList();
        filteredCards = List.from(cards);
      });
      await fetchAllCronogramas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las tarjetas: $e')),
      );
    }
  }

  Future<void> fetchAllCronogramas() async {
    for (var card in cards) {
      try {
        final data = await api_service.ApiService.getMaintenanceData(card.id);
        List<dynamic> rawCronogramas = data['cronogramas'] ?? [];
        List<maintenance_page.CronogramaEvento> parsedCronogramas = rawCronogramas.map<maintenance_page.CronogramaEvento>((item) {
          if (item is Map<String, dynamic>) {
            return maintenance_page.CronogramaEvento.fromJson(item);
          } else if (item.runtimeType.toString() == 'CronogramaEvento') {
            return item;
          } else {
            throw Exception('Unexpected type in cronogramas list: ${item.runtimeType}');
          }
        }).toList();
        print('Card ID: ${card.id}, Cronogramas: $parsedCronogramas'); 
        setState(() {
          cardCronogramas[card.id] = parsedCronogramas;
        });
      } catch (e) {
        print('Error fetching cronogramas for card ${card.id}: $e'); 
      }
    }
  }

  bool hasUpcomingCronograma(int cardId) {
    final cronogramas = cardCronogramas[cardId];
    if (cronogramas == null || cronogramas.isEmpty) return false;

    final now = DateTime.now();
    final sevenDaysFromNow = now.add(Duration(days: 7));

    for (var event in cronogramas) {
      DateTime eventDate;
      bool completed = false;
      if (event is Map && event.containsKey('date')) {
        eventDate = DateTime.parse(event['date']);
        completed = event['completed'] ?? false;
      } else if (event is maintenance_page.CronogramaEvento) {
        eventDate = event.date;
        completed = event.completed;
      } else {
        continue;
      }
      if (eventDate.isAfter(now) && eventDate.isBefore(sevenDaysFromNow) && !completed) {
        return true;
      }
    }
    return false;
  }

  void applyFilters() {
    setState(() {
      filteredCards = cards.where((card) {
        final searchText = searchController.text.toLowerCase();
        final nameFilter = nameFilterController.text.toLowerCase();
        final modelFilter = modelFilterController.text.toLowerCase();
        final brandFilter = brandFilterController.text.toLowerCase();

        bool matches = true;

        if (searchText.isNotEmpty) {
          matches = card.name.toLowerCase().contains(searchText) ||
              card.status.toLowerCase().contains(searchText) ||
              card.model.toLowerCase().contains(searchText) ||
              card.brand.toLowerCase().contains(searchText);
        }

        if (nameFilter.isNotEmpty && !card.name.toLowerCase().contains(nameFilter)) {
          matches = false;
        }

        if (statusFilter.isNotEmpty && !card.status.toLowerCase().contains(statusFilter.toLowerCase())) {
          matches = false;
        }

        if (modelFilter.isNotEmpty && !card.model.toLowerCase().contains(modelFilter)) {
          matches = false;
        }

        if (brandFilter.isNotEmpty && !card.brand.toLowerCase().contains(brandFilter)) {
          matches = false;
        }

        return matches;
      }).toList();
    });
  }

  void clearFilters() {
    setState(() {
      searchController.clear();
      nameFilterController.clear();
      modelFilterController.clear();
      brandFilterController.clear();
      statusFilter = '';
      filteredCards = List.from(cards);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        pageTitle: 'Inventario',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 10,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar tarjeta...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => applyFilters(),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.filter_list),
                    onPressed: () {
                      setState(() {
                        isFilterMenuVisible = !isFilterMenuVisible;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          if (isFilterMenuVisible)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filtrar por:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(
                    controller: nameFilterController,
                    decoration: InputDecoration(
                      hintText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => applyFilters(),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                    value: statusFilter.isEmpty ? null : statusFilter,
                    items: [
                      DropdownMenuItem(child: Text('Estado'), value: ''),
                      DropdownMenuItem(child: Text('Activo'), value: 'Activo'),
                      DropdownMenuItem(child: Text('Fuera de servicio'), value: 'Fuera de servicio'),
                    ],
                    onChanged: (value) {
                      setState(() {
                        statusFilter = value ?? '';
                        applyFilters();
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: modelFilterController,
                    decoration: InputDecoration(
                      hintText: 'Modelo',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => applyFilters(),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: brandFilterController,
                    decoration: InputDecoration(
                      hintText: 'Marca',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => applyFilters(),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    child: Text('Limpiar filtros'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    onPressed: clearFilters,
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  childAspectRatio: 2.0,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                itemCount: filteredCards.length,
                itemBuilder: (context, index) {
                  final card = filteredCards[index];
                final hasUpcoming = hasUpcomingCronograma(card.id);
                Color borderColor;
                if (hasUpcoming) {
                  borderColor = Colors.yellow;
                } else {
                  borderColor = card.status == 'Fuera de servicio' ? Colors.red : Colors.green;
                }
                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CardDetailPage(cardId: card.id),
                        ),
                      );
                      if (result == true) {
                        fetchCards();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: borderColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: card.imageUrl.isNotEmpty
                                  ? Image.network(
                                      card.imageUrl.startsWith('http')
                                          ? card.imageUrl
                                      : '${api_service.ApiService.baseUrl}${card.imageUrl}',
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                      height: 80,
                      child: Icon(Icons.image_not_supported, size: 40),
                    ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text('Estado: ${card.status}'),
                                  Text('Modelo: ${card.model}'),
                                  Text('Marca: ${card.brand}'),
                                  Text('Riesgo: ${card.risk}'),
                                  Text('Ubicación: ${card.location}'),
                                ],
                              ),
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddCardDialog(
              onCardAdded: () {
                fetchCards();
              },
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class CardDetailPage extends StatefulWidget {
  final int cardId;

  CardDetailPage({required this.cardId});

  @override
  _CardDetailPageState createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  Map<String, dynamic>? cardDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCardDetails();
  }

  Future<void> fetchCardDetails() async {
    try {
      final Map<String, dynamic> cardJson = await api_service.ApiService.fetchCardDetail(widget.cardId);
      setState(() {
        cardDetails = cardJson;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar los detalles: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(false);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: CustomAppBar(
          pageTitle: 'Detalles',
          showBackButton: true,
          onBackPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomePage()),
              (route) => false,
            );
          },
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : cardDetails == null
                ? Center(child: Text('No se encontraron detalles'))
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cardDetails!['image'] != null)
                          Center(
                              child: Image.network(
                                cardDetails!['image'].startsWith('http')
                                    ? cardDetails!['image']
                                    : '${api_service.ApiService.baseUrl}${cardDetails!['image']}',
                                height: 200,
                              ),
                          ),
                        SizedBox(height: 16),
                        Text(
                          cardDetails!['name'] ?? '',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        CardInfoItem(title: 'Estado', value: cardDetails!['status'] ?? ''),
                        CardInfoItem(title: 'Marca', value: cardDetails!['brand'] ?? ''),
                        CardInfoItem(title: 'Modelo', value: cardDetails!['model'] ?? ''),
                        CardInfoItem(title: 'Serie', value: cardDetails!['series'] ?? ''),
                        CardInfoItem(title: 'Riesgo', value: cardDetails!['risk'] ?? ''),
                        CardInfoItem(title: 'Ubicación', value: cardDetails!['location'] ?? ''),
                        SizedBox(height: 24),
        ElevatedButton(
          onPressed: () async {
            setState(() {
              if (cardDetails!['status'] == 'Fuera de servicio') {
                cardDetails!['status'] = 'En servicio';
              } else {
                cardDetails!['status'] = 'Fuera de servicio';
              }
            });
            try {
              final response = await http.post(
                Uri.parse('${api_service.ApiService.baseUrl}/toggle_status/${widget.cardId}/'),
                headers: {
                  'Content-Type': 'application/json',
                },
              );
              if (response.statusCode == 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Estado cambiado a ${cardDetails!['status']}')),
                );
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al cambiar estado: ${response.statusCode}')),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al cambiar estado: $e')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
          child: Text('Cambiar estado del equipo'),
        ),
                        SizedBox(height: 16),
                        /*
                        ElevatedButton(
                          onPressed: () async {
                            final updated = await showDialog<bool>(
                              context: context,
                              builder: (context) => EditCardDialog(
                                cardDetails: cardDetails!,
                              ),
                            );
                            if (updated == true) {
                              fetchCardDetails();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 48),
                          ),
                          child: Text('Editar tarjeta'),
                        ),
                        */
                      ],
                    ),
                  ),
        bottomNavigationBar: CustomDetailBottomBar(cardId: widget.cardId, currentPage: '/card_detail/\${widget.cardId}'),
      ),
    );
  }
}

class EditCardDialog extends StatefulWidget {
  final Map<String, dynamic> cardDetails;

  EditCardDialog({required this.cardDetails});

  @override
  _EditCardDialogState createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<EditCardDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController brandController;
  late TextEditingController modelController;
  late TextEditingController seriesController;
  late TextEditingController locationController;
  late String risk;
  late String status;
  File? imageFile;
  final storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.cardDetails['name']);
    brandController = TextEditingController(text: widget.cardDetails['brand']);
    modelController = TextEditingController(text: widget.cardDetails['model']);
    seriesController = TextEditingController(text: widget.cardDetails['series']);
    locationController = TextEditingController(text: widget.cardDetails['location'] ?? '');
    risk = widget.cardDetails['risk'] ?? 'I';
    status = widget.cardDetails['status'] ?? 'Activo';
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final csrfToken = await storage.read(key: 'csrftoken');
        final uri = Uri.parse('${api_service.ApiService.baseUrl}cards/${widget.cardDetails['id']}/');

        var request = http.MultipartRequest('PUT', uri);

        request.fields['name'] = nameController.text;
        request.fields['brand'] = brandController.text;
        request.fields['model'] = modelController.text;
        request.fields['series'] = seriesController.text;
        request.fields['risk'] = risk;
        request.fields['location'] = locationController.text;
        request.fields['status'] = status;

        if (imageFile != null) {
          request.files.add(await http.MultipartFile.fromPath('image', imageFile!.path));
        }

        request.headers['X-CSRFToken'] = csrfToken ?? '';

        final response = await request.send();

        if (response.statusCode == 200) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tarjeta actualizada exitosamente')),
          );
        } else {
          final responseData = await response.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode} - $responseData')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar tarjeta'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese un nombre';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: pickImage,
                child: Text('Seleccionar imagen'),
              ),
              if (imageFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(
                    imageFile!,
                    height: 100,
                  ),
                ),
              TextFormField(
                controller: brandController,
                decoration: InputDecoration(labelText: 'Marca'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una marca';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: modelController,
                decoration: InputDecoration(labelText: 'Modelo'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese un modelo';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: seriesController,
                decoration: InputDecoration(labelText: 'Serie'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una serie';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Clasificación por riesgo'),
                value: risk,
                items: [
                  DropdownMenuItem(child: Text('I'), value: 'I'),
                  DropdownMenuItem(child: Text('IIA'), value: 'IIA'),
                  DropdownMenuItem(child: Text('IIB'), value: 'IIB'),
                  DropdownMenuItem(child: Text('III'), value: 'III'),
                ],
                onChanged: (value) {
                  setState(() {
                    risk = value!;
                  });
                },
              ),
              TextFormField(
                controller: locationController,
                decoration: InputDecoration(labelText: 'Ubicación'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una ubicación';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Estado'),
                value: (status == 'En servicio') ? 'Activo' : status,
                items: [
                  DropdownMenuItem(child: Text('Activo'), value: 'Activo'),
                  DropdownMenuItem(child: Text('Fuera de servicio'), value: 'Fuera de servicio'),
                ],
                onChanged: (value) {
                  setState(() {
                    status = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: submitForm,
          child: Text('Guardar'),
        ),
      ],
    );
  }
}

class CardInfoItem extends StatelessWidget {
  final String title;
  final String value;

  CardInfoItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class AddCardDialog extends StatefulWidget {
  final Function onCardAdded;

  AddCardDialog({required this.onCardAdded});

  @override
  _AddCardDialogState createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final seriesController = TextEditingController();
  final locationController = TextEditingController();
  String risk = 'I';
  String status = 'Activo';
  File? imageFile;
  final storage = FlutterSecureStorage();

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final csrfToken = await storage.read(key: 'csrftoken');
        final uri = Uri.parse('${api_service.ApiService.baseUrl}/cards/');
        
        var request = http.MultipartRequest('POST', uri);
        
        request.fields['name'] = nameController.text;
        request.fields['brand'] = brandController.text;
        request.fields['model'] = modelController.text;
        request.fields['series'] = seriesController.text;
        request.fields['risk'] = risk;
        request.fields['location'] = locationController.text;
        request.fields['status'] = status;
        
        if (imageFile != null) {
          request.files.add(await http.MultipartFile.fromPath('image', imageFile!.path));
        }
        
        request.headers['X-CSRFToken'] = csrfToken ?? '';
        
        final response = await request.send();
        
        if (response.statusCode == 201) {
          Navigator.of(context).pop();
          widget.onCardAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tarjeta agregada exitosamente')),
          );
        } else {
          final responseData = await response.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode} - $responseData')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar nueva tarjeta'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese un nombre';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: pickImage,
                child: Text('Seleccionar imagen'),
              ),
              if (imageFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(
                    imageFile!,
                    height: 100,
                  ),
                ),
              TextFormField(
                controller: brandController,
                decoration: InputDecoration(labelText: 'Marca'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una marca';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: modelController,
                decoration: InputDecoration(labelText: 'Modelo'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese un modelo';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: seriesController,
                decoration: InputDecoration(labelText: 'Serie'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una serie';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Clasificación por riesgo'),
                value: risk,
                items: [
                  DropdownMenuItem(child: Text('I'), value: 'I'),
                  DropdownMenuItem(child: Text('IIA'), value: 'IIA'),
                  DropdownMenuItem(child: Text('IIB'), value: 'IIB'),
                  DropdownMenuItem(child: Text('III'), value: 'III'),
                ],
                onChanged: (value) {
                  setState(() {
                    risk = value!;
                  });
                },
              ),
              TextFormField(
                controller: locationController,
                decoration: InputDecoration(labelText: 'Ubicación'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese una ubicación';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Estado'),
                value: status,
                items: [
                  DropdownMenuItem(child: Text('Activo'), value: 'Activo'),
                  DropdownMenuItem(child: Text('Fuera de servicio'), value: 'Fuera de servicio'),
                ],
                onChanged: (value) {
                  setState(() {
                    status = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: submitForm,
          child: Text('Guardar'),
        ),
      ],
    );
  }
}