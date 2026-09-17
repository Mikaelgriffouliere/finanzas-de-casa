// Genera el ícono de la app (assets/icon/icon.png, 1024x1024) con el lenguaje
// visual de la marca: gradiente hero + tarjeta de pago blanca.
//
// Uso: dart run tool/generate_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const int size = 1024;

const indigo = [0x4F, 0x5C, 0xD3];
const cyan = [0x0F, 0xA3, 0xC5];
const emerald = [0x22, 0xC3, 0xA6];

int _lerpChannel(int a, int b, double t) => (a + (b - a) * t).round();

List<int> _lerp(List<int> a, List<int> b, double t) => [
  _lerpChannel(a[0], b[0], t),
  _lerpChannel(a[1], b[1], t),
  _lerpChannel(a[2], b[2], t),
];

void _set(img.Image image, int x, int y, List<int> rgb) {
  image.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
}

void _setA(img.Image image, int x, int y, int a) {
  image.setPixelRgba(x, y, 255, 255, 255, a);
}

/// Rectángulos de la "tarjeta" del ícono, reutilizados por ambas versiones.
({double cardX, double cardY, double cardW, double cardH, double corner,
    double chipX, double chipY, double chipW, double chipH,
    List<double> lineY, List<double> lineW, double lineX, double lineH})
_geometry() {
  final cardX = size * 0.20;
  final cardY = size * 0.27;
  final cardW = size * 0.60;
  final cardH = size * 0.46;
  final corner = size * 0.095;
  final chipX = cardX + size * 0.10;
  final chipY = cardY + size * 0.12;
  final chipW = size * 0.13;
  final chipH = chipW * 0.8;
  final lineX = cardX + size * 0.10;
  var lineY = <double>[];
  var lineW = <double>[];
  for (var i = 0; i < 3; i++) {
    lineY.add(chipY + chipH + size * (0.09 + i * 0.085));
    lineW.add(size * (0.30 - i * 0.06));
  }
  return (
    cardX: cardX,
    cardY: cardY,
    cardW: cardW,
    cardH: cardH,
    corner: corner,
    chipX: chipX,
    chipY: chipY,
    chipW: chipW,
    chipH: chipH,
    lineY: lineY,
    lineW: lineW,
    lineX: lineX,
    lineH: size * 0.022,
  );
}

bool _inRoundedRect(
  double x,
  double y,
  double rx,
  double ry,
  double w,
  double h,
  double r,
) {
  if (x < rx || x >= rx + w || y < ry || y >= ry + h) return false;
  final dx = x < rx + r
      ? x - (rx + r)
      : (x >= rx + w - r ? x - (rx + w - r) : 0);
  final dy = y < ry + r
      ? y - (ry + r)
      : (y >= ry + h - r ? y - (ry + h - r) : 0);
  return dx * dx + dy * dy <= r * r;
}

void main() {
  final g = _geometry();
  final image = img.Image(width: size, height: size);

  // Fondo: gradiente diagonal índigo -> cian -> esmeralda.
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = ((x / size) + (y / size)) / 2; // 0..1 (esquina TL a BR)
      final half = _lerp(indigo, cyan, t < 0.55 ? t / 0.55 : 1.0);
      final color = t < 0.55 ? half : _lerp(cyan, emerald, (t - 0.55) / 0.45);
      _set(image, x, y, color);
    }
  }

  // Tarjeta blanca central.
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (_inRoundedRect(
        x.toDouble(),
        y.toDouble(),
        g.cardX,
        g.cardY,
        g.cardW,
        g.cardH,
        g.corner,
      )) {
        _set(image, x, y, [255, 255, 255]);
      }
    }
  }

  // Chip (rectángulo pequeño con el gradiente de marca).
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (_inRoundedRect(
        x.toDouble(),
        y.toDouble(),
        g.chipX,
        g.chipY,
        g.chipW,
        g.chipH,
        size * 0.025,
      )) {
        final t = ((x - g.chipX) + (y - g.chipY)) / (g.chipW + g.chipH);
        final color = t < 0.55
            ? _lerp(indigo, cyan, t / 0.55)
            : _lerp(cyan, emerald, (t - 0.55) / 0.45);
        _set(image, x, y, color);
      }
    }
  }

  // Líneas de "texto" decorativas.
  final lineColors = const [0xFF8B93C7, 0xFFA6ADCB, 0xFFC4C9DC];
  for (var i = 0; i < lineColors.length; i++) {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (_inRoundedRect(
          x.toDouble(),
          y.toDouble(),
          g.lineX,
          g.lineY[i],
          g.lineW[i],
          g.lineH,
          g.lineH / 2,
        )) {
          _set(image, x, y, [
            (lineColors[i] >> 16) & 0xFF,
            (lineColors[i] >> 8) & 0xFF,
            lineColors[i] & 0xFF,
          ]);
        }
      }
    }
  }

  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Ícono generado en assets/icon/icon.png');

  _generateMonochrome(g);
}

void _generateMonochrome(g) {
  final image = img.Image(width: size, height: size, numChannels: 4); // transparente

  // Tarjeta blanca (opaca) con "huecos" (transparentes) para chip y líneas.
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final px = x.toDouble();
      final py = y.toDouble();
      final inCard = _inRoundedRect(px, py, g.cardX, g.cardY, g.cardW, g.cardH, g.corner);
      var punched = false;
      if (inCard) {
        if (_inRoundedRect(px, py, g.chipX, g.chipY, g.chipW, g.chipH, size * 0.025)) {
          punched = true;
        } else {
          for (var i = 0; i < g.lineY.length; i++) {
            if (_inRoundedRect(px, py, g.lineX, g.lineY[i], g.lineW[i], g.lineH, g.lineH / 2)) {
              punched = true;
              break;
            }
          }
        }
      }
      if (inCard && !punched) {
        _setA(image, x, y, 255);
      }
    }
  }

  File('assets/icon/icon_monochrome.png').writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Ícono monocromo generado en assets/icon/icon_monochrome.png');
}
