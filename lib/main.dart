import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const MaterialApp(
    home: PdfViewer(),
    debugShowCheckedModeBanner: false,
  ));
}

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  final Map<String, Uint8List> _signedFields = <String, Uint8List>{};
  PdfDocument? _loadedDocument;
  Uint8List? _documentBytes;
  bool _canCompleteSigning = false;
  bool _canShowToast = false;

  @override
  void initState() {
    super.initState();
    // Load the PDF document from the asset.
    _readAsset('lease_agreement.pdf').then((List<int> bytes) async {
      setState(() {
        _documentBytes = Uint8List.fromList(bytes);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digitally sign the agreement'),
        actions: [
          ElevatedButton(
            onPressed: _canCompleteSigning ? _signDocument : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canCompleteSigning
                  ? Theme.of(context).colorScheme.primary
                  : null,
              disabledBackgroundColor: _canCompleteSigning
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              foregroundColor: _canCompleteSigning
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
            ),
            child: const Text('Complete Signing'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_canShowToast)
            Container(
              color: Colors.green,
              alignment: Alignment.center,
              child: const Text(
                ' The agreement has been digitally signed successfully.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          Expanded(
            child: _documentBytes != null
                ? SfPdfViewer.memory(
                    _documentBytes!,
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      // Store the loaded document to access the form fields.
                      _loadedDocument = details.document;
                      // Clear the signed fields when the document is loaded.
                      _signedFields.clear();
                    },
                    onFormFieldValueChanged:
                        (PdfFormFieldValueChangedDetails details) {
                      // Update the signed fields when the form field value is changed.
                      if (details.formField is PdfSignatureFormField) {
                        final PdfSignatureFormField signatureField =
                            details.formField as PdfSignatureFormField;
                        if (signatureField.signature != null) {
                          _signedFields[details.formField.name] =
                              signatureField.signature!;
                          setState(() {
                            _canCompleteSigning = true;
                          });
                        } else {
                          _signedFields.remove(details.formField.name);
                          setState(() {
                            _canCompleteSigning = false;
                          });
                        }
                      }
                    },
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
        ],
      ),
    );
  }

  // Read the asset file and return the bytes.
  Future<List<int>> _readAsset(String name) async {
    final ByteData data = await rootBundle.load('assets/$name');
    return data.buffer.asUint8List();
  }

  // Digitally sign the document and reload it in the viewer.
  Future<void> _signDocument() async {
    if (_loadedDocument != null) {
      for (int fieldIndex = 0;
          fieldIndex < _loadedDocument!.form.fields.count;
          fieldIndex++) {
        final PdfField pdfField = _loadedDocument!.form.fields[fieldIndex];

        if (pdfField is PdfSignatureField &&
            _signedFields.containsKey(pdfField.name)) {
          final PdfSignatureField signatureField = pdfField;
          if (signatureField.signature == null) {
            // Load the certificate from the asset.
            final PdfCertificate certificate = PdfCertificate(
                await _readAsset('certificate.pfx'), 'password123');

            // Add the signature to the signature field.
            signatureField.signature = PdfSignature(
              certificate: certificate,
              contactInfo: 'johndoe@owned.us',
              locationInfo: 'Honolulu, Hawaii',
              reason: 'I am author of this document.',
            );

            // Draw the signature image to the signature field.
            signatureField.appearance.normal.graphics?.drawImage(
              PdfBitmap(
                _signedFields[pdfField.name]!,
              ),
              Offset.zero & signatureField.bounds.size,
            );
            _canCompleteSigning = false;
          }
        }
      }
      // Save the signed document.
      final List<int> bytes = await _loadedDocument!.save();
      // Update the document bytes to reflect the changes.
      setState(() {
        _documentBytes = Uint8List.fromList(bytes);
        _canShowToast = true;
      });
      Future<void>.delayed(const Duration(seconds: 5), () {
        setState(() {
          _canShowToast = false;
        });
      });
    }
  }
}
