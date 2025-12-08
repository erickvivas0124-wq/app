import 'package:flutter/material.dart';
import '../pages/card_documents_page.dart';
import '../pages/maintenancepage.dart';
import '../pages/historialpage.dart';

class CustomDetailBottomBar extends StatelessWidget {
  final int cardId;
  final String currentPage;

  const CustomDetailBottomBar({Key? key, required this.cardId, required this.currentPage}) : super(key: key);

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Código QR del equipo'),
        content: Image.network('http://192.168.1.4:8000/generate_qr/$cardId/',
          fit: BoxFit.contain,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeName) {
    if (currentPage == routeName) {
      return;
    }
    final currentRoute = ModalRoute.of(context);
    if (routeName.startsWith('/card_documents/')) {
      final cardIdStr = routeName.split('/').last;
      final cardId = int.tryParse(cardIdStr);
      if (cardId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CardDocumentsScreen(cardId: cardId, cardName: 'Equipo $cardId'),
          ),
        );
        return;
      }
    } else if (routeName.startsWith('/card_maintenance/')) {
      final cardIdStr = routeName.split('/').last;
      final cardId = int.tryParse(cardIdStr) ?? 0;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MaintenanceScreen(cardId: cardId),
        ),
      );
      return;
    } else if (routeName.startsWith('/card_history/')) {
      final cardIdStr = routeName.split('/').last;
      final cardId = int.tryParse(cardIdStr) ?? 0;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CardHistoryPage(cardId: cardId),
        ),
      );
      return;
    }
    Navigator.of(context).popUntil((route) => route.settings.name == null || route.settings.name == '/');
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton(
            onPressed: () => _navigateTo(context, '/card_documents/$cardId'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file, size: 28, color: Colors.black54),
                SizedBox(height: 4),
                Text('Documentos', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showQrDialog(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code, size: 28, color: Colors.black54),
                SizedBox(height: 4),
                Text('QR', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateTo(context, '/card_maintenance/$cardId'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.build, size: 28, color: Colors.black54),
                SizedBox(height: 4),
                Text('Actividades', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateTo(context, '/card_history/$cardId'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 28, color: Colors.black54),
                SizedBox(height: 4),
                Text('Historial', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
