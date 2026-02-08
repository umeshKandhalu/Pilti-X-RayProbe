import 'dart:html' as html;

void downloadFile(List<int> bytes, String fileName) {
  print("DEBUG: downloadFile started for $fileName. Size: ${bytes.length} bytes");
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..style.display = 'none';
      
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
    print("DEBUG: downloadFile anchor clicked and removed");
  } catch (e) {
    print("ERROR: downloadFile failed: $e");
    rethrow;
  }
}

void viewFile(List<int> bytes, String fileName) {
  print("DEBUG: viewFile started for $fileName");
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..target = "_blank"
      ..click();
      
    Future.delayed(const Duration(seconds: 30), () {
      html.Url.revokeObjectUrl(url);
    });
    print("DEBUG: viewFile tab launch triggered");
  } catch (e) {
    print("ERROR: viewFile failed: $e");
    rethrow;
  }
}
