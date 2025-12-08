import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../main.dart' as main_app;
import '../api_service.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String pageTitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final PreferredSizeWidget? bottom;

  CustomAppBar({
    Key? key,
    required this.pageTitle,
    this.showBackButton = false,
    this.onBackPressed,
    this.bottom,
  })  : preferredSize = Size.fromHeight(
          kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
        ),
        super(key: key);

  @override
  final Size preferredSize;

  @override
  _CustomAppBarState createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  void _openQrScanner() async {
    if (kIsWeb) return; // QR scanner not available on web
    // QR scanner code would go here for mobile
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('QR scanner not available on web')),
    );
  }

   Future<void> _exportToExcel() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/cards_export.xlsx';
      final file = File(filePath);

      final bytes = await ApiService.exportCardsToExcel();

      await file.writeAsBytes(bytes);

      await Share.shareFiles([filePath], text: 'Excel exportado');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel exportado exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
return AppBar(
      backgroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.black),
      automaticallyImplyLeading: false,
      bottom: widget.bottom,
      title: widget.showBackButton
          ? Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    widget.pageTitle,
                    style: TextStyle(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 48), 
              ],
            )
          : Text(
              widget.pageTitle,
              style: TextStyle(color: Colors.black),
            ),
      actions: [
        if (!kIsWeb)
          IconButton(
            icon: FaIcon(FontAwesomeIcons.qrcode, color: Colors.black),
            onPressed: _openQrScanner,
            tooltip: 'Scan QR',
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.menu, color: Colors.black),
              onSelected: (value) {
                switch (value) {
                  case 'home':
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    break;
                  case 'cronograma':
                    Navigator.of(context).pushNamed('/generalhistory');
                    break;
                  case 'import':
                    Navigator.of(context).pushNamed('/import');
                    break;
                  case 'calendario':
                    Navigator.of(context).pushNamed('/calendar_screen');
                    break;
                  case 'export':
                    _exportToExcel();
                    break;                   
                }
              },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'home',
              child: Text('Inventario'),
            ),
            PopupMenuItem(
              value: 'cronograma',
              child: Text('Gestionar Tarjetas'),
            ),
            PopupMenuItem(
              value: 'import',
              child: Text('Importar Datos'),
            ),
            PopupMenuItem(
              value: 'calendario',
              child: Text('Calendario'),
            ),
            PopupMenuItem(
              value: 'export',
              child: Text('Exportar a Excel'),
            ),
          ],
        ),
      ],
    );
  }
}
