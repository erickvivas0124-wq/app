import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_service.dart' as api_service;
import '../widgets/custom_app_bar.dart';

class Card {
  final int id;
  final String name;
  final String status;
  final String model;
  final String brand;
  final String imageUrl;
  final bool isDeleted;

  Card({
    required this.id,
    required this.name,
    required this.status,
    required this.model,
    required this.brand,
    this.imageUrl = '',
    this.isDeleted = false,
  });

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      id: json['id'],
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      model: json['model'] ?? '',
      brand: json['brand'] ?? '',
      imageUrl: json['image'] ?? '',
      isDeleted: json['is_deleted'] ?? false,
    );
  }
}

class ManageCardsPage extends StatefulWidget {
  @override
  _ManageCardsPageState createState() => _ManageCardsPageState();
}

class _ManageCardsPageState extends State<ManageCardsPage>
    with SingleTickerProviderStateMixin {
  List<Card> activeCards = [];
  List<Card> deletedCards = [];
  List<Card> filteredActiveCards = [];
  List<Card> filteredDeletedCards = [];
  bool isFilterMenuVisible = false;
  late TabController _tabController;

  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameFilterController = TextEditingController();
  final TextEditingController modelFilterController = TextEditingController();
  final TextEditingController brandFilterController = TextEditingController();
  String statusFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchCards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    nameFilterController.dispose();
    modelFilterController.dispose();
    brandFilterController.dispose();
    super.dispose();
  }

  Future<void> fetchCards() async {
    try {
      final List<dynamic> activeJsonData = await api_service.ApiService.fetchCards();
      
      final List<dynamic> deletedJsonData = await api_service.ApiService.fetchDeletedCards();

      setState(() {
        activeCards = activeJsonData.map((json) => Card.fromJson(json)).toList();
        deletedCards = deletedJsonData.map((json) => Card.fromJson(json)).toList();
        filteredActiveCards = List.from(activeCards);
        filteredDeletedCards = List.from(deletedCards);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las tarjetas: $e')),
      );
    }
  }

  Future<void> deleteCard(int cardId) async {
    try {
      final response = await http.post(
        Uri.parse('${api_service.ApiService.baseUrl}/cards/$cardId/soft_delete/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarjeta eliminada exitosamente')),
        );
        fetchCards(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la tarjeta: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la tarjeta: $e')),
      );
    }
  }

  Future<void> restoreCard(int cardId) async {
    try {
      final response = await http.post(
        Uri.parse('${api_service.ApiService.baseUrl}/cards/$cardId/restore/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarjeta restaurada exitosamente')),
        );
        fetchCards(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar la tarjeta: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al restaurar la tarjeta: $e')),
      );
    }
  }

  void applyFilters() {
    setState(() {
      filteredActiveCards = _filterCards(activeCards);
      filteredDeletedCards = _filterCards(deletedCards);
    });
  }

  List<Card> _filterCards(List<Card> cards) {
    return cards.where((card) {
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
  }

  void clearFilters() {
    setState(() {
      searchController.clear();
      nameFilterController.clear();
      modelFilterController.clear();
      brandFilterController.clear();
      statusFilter = '';
      filteredActiveCards = List.from(activeCards);
      filteredDeletedCards = List.from(deletedCards);
    });
  }

  Widget _buildFilterMenu() {
    if (!isFilterMenuVisible) return SizedBox.shrink();

    return Container(
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
    );
  }

  Widget _buildCardItem(Card card, bool isDeleted) {
    Color borderColor = isDeleted 
        ? Colors.grey 
        : (card.status == 'Fuera de servicio' ? Colors.red : Colors.green);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
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
                      height: 80,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDeleted ? Colors.grey : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Estado: ${card.status}',
                    style: TextStyle(
                      color: isDeleted ? Colors.grey : Colors.black,
                    ),
                  ),
                  Text(
                    'Modelo: ${card.model}',
                    style: TextStyle(
                      color: isDeleted ? Colors.grey : Colors.black,
                    ),
                  ),
                  Text(
                    'Marca: ${card.brand}',
                    style: TextStyle(
                      color: isDeleted ? Colors.grey : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: isDeleted
                  ? ElevatedButton(
                      onPressed: () => _showRestoreDialog(card),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Icon(Icons.restore),
                    )
                  : ElevatedButton(
                      onPressed: () => _showDeleteDialog(card),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Icon(Icons.delete),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Card card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar la tarjeta "${card.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                deleteCard(card.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreDialog(Card card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar restauración'),
          content: Text('¿Estás seguro de que quieres restaurar la tarjeta "${card.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                restoreCard(card.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Restaurar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        pageTitle: 'Gestionar Tarjetas',
        showBackButton: true,
        onBackPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Activas (${filteredActiveCards.length})',
              icon: Icon(Icons.inventory),
            ),
            Tab(
              text: 'Eliminadas (${filteredDeletedCards.length})',
              icon: Icon(Icons.delete_outline),
            ),
          ],
        ),
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
          _buildFilterMenu(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: filteredActiveCards.isEmpty
                      ? Center(
                          child: Text(
                            'No hay tarjetas activas',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredActiveCards.length,
                          itemBuilder: (context, index) {
                            final card = filteredActiveCards[index];
                            return _buildCardItem(card, false);
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: filteredDeletedCards.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No hay tarjetas eliminadas',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredDeletedCards.length,
                          itemBuilder: (context, index) {
                            final card = filteredDeletedCards[index];
                            return _buildCardItem(card, true);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
