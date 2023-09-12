import 'package:graphic/src/chart/chart.dart';
import 'package:graphic/src/chart/graphic_view.dart';
import 'package:graphic/src/common/defaults.dart';
import 'package:graphic/src/common/dim.dart';
import 'package:graphic/src/common/label.dart';
import 'package:graphic/src/common/intrinsic_layers.dart';
import 'package:graphic/src/common/operators/render.dart';
import 'package:graphic/src/common/styles.dart';
import 'package:graphic/src/coord/coord.dart';
import 'package:graphic/src/coord/polar.dart';
import 'package:graphic/src/coord/rect.dart';
import 'package:graphic/src/dataflow/operator.dart';
import 'package:graphic/src/graffiti/scene.dart';
import 'package:graphic/src/guide/axis/circular.dart';
import 'package:graphic/src/guide/axis/horizontal.dart';
import 'package:graphic/src/guide/axis/radial.dart';
import 'package:graphic/src/guide/axis/vertical.dart';
import 'package:graphic/src/scale/scale.dart';
import 'package:graphic/src/util/assert.dart';

/// The specification of a single axis tick line.
class TickLine {
  /// Creates a tick line.
  TickLine({
    StrokeStyle? style,
    this.length = 5,
  }) : style = style ?? Defaults.strokeStyle;

  /// The stroke style of this tick line.
  StrokeStyle style;

  /// The length of this tick line.
  double length;

  @override
  bool operator ==(Object other) =>
      other is TickLine && style == other.style && length == other.length;
}

/// Gets an axis tick line form an axis value text.
///
/// [index] and [total] is current and total count of all ticks respectively.
typedef TickLineMapper = TickLine? Function(String? text, int index, int total);

/// Gets an axis label form an axis value text.
///
/// [index] and [total] is current and total count of all ticks respectively.
typedef LabelMapper = LabelStyle? Function(String? text, int index, int total);

/// Gets an axis grid stroke style form an axis value text.
///
/// [index] and [total] is current and total count of all ticks respectively.
typedef GridMapper = StrokeStyle? Function(String? text, int index, int total);

/// The specification of an axis.
///
/// There can be mutiple axes in one dimension.
class AxisGuide<V> {
  /// Creates an axis.
  AxisGuide({
    this.dim,
    this.variable,
    this.position,
    this.flip,
    this.line,
    this.tickLine,
    this.tickLineMapper,
    this.label,
    this.labelMapper,
    this.grid,
    this.gridMapper,
    this.layer,
    this.gridZIndex,
  })  : assert(isSingle([tickLine, tickLineMapper], allowNone: true)),
        assert(isSingle([label, labelMapper], allowNone: true)),
        assert(isSingle([grid, gridMapper], allowNone: true));

  /// The dimension where this axis lies.
  ///
  /// If null, it will be set according to the order in [Chart.axes].
  Dim? dim;

  /// The variable this axis is binded to.
  ///
  /// If null, the first variable assigned to [dim] is set by default.
  String? variable;

  /// The position ratio in the crossing dimension where this axis line stands.
  ///
  /// This ratio is to region boundaries for [RectCoord] and to angle or radius
  /// boundaries for [PolarCoord].
  ///
  /// If null, a default 0 is set.
  double? position;

  /// Whether to flip tick lines and labels to the other side of the axis line.
  ///
  /// The default side is left for vertical axes, bottom for horizontal axes, outer
  /// for circular axes, and behind the anticlockwise for radial axes.
  bool? flip;

  /// The stroke style for the axis line.
  ///
  /// If null, there will be no axis line.
  StrokeStyle? line;

  /// The tick line settings for all ticks.
  ///
  /// Only one in [tickLine] and [tickLineMapper] can be set.
  ///
  /// If null and [tickLineMapper] is also null, there will be no tick lines.
  TickLine? tickLine;

  /// Indicates how to get the tick line setting for each tick.
  ///
  /// Only one in [tickLine] and [tickLineMapper] can be set.
  TickLineMapper? tickLineMapper;

  /// The label style for all ticks.
  ///
  /// Only one in [label] and [labelMapper] can be set.
  ///
  /// If null and [labelMapper] is also null, there will be no labels.
  LabelStyle? label;

  /// Indicates how to get the label style for each tick.
  ///
  /// Only one in [label] and [labelMapper] can be set.
  LabelMapper? labelMapper;

  /// The grid stroke style for all ticks.
  ///
  /// Only one in [grid] and [gridMapper] can be set.
  ///
  /// If null and [gridMapper] is also null, there will be no grids.
  StrokeStyle? grid;

  /// Indicates how to get the grid stroke style for each tick.
  ///
  /// Only one in [grid] and [gridMapper] can be set.
  GridMapper? gridMapper;

  /// The layer of this axis.
  ///
  /// If null, a default 0 is set.
  int? layer;

  /// The layer of the grids.
  ///
  /// If null, a default 0 is set.
  int? gridZIndex;

  @override
  bool operator ==(Object other) =>
      other is AxisGuide &&
      dim == other.dim &&
      variable == other.variable &&
      position == other.position &&
      flip == other.flip &&
      line == other.line &&
      tickLine == other.tickLine &&
      label == other.label &&
      grid == other.grid &&
      layer == other.layer &&
      gridZIndex == other.gridZIndex;
}

/// Information of a single tick.
class TickInfo {
  TickInfo(
    this.position,
    this.text,
  );

  /// The tick position.
  final double position;

  /// The text of the tick label.
  final String? text;

  /// The tick line specification.
  TickLine? tickLine;

  /// The tyle of the tick label.
  LabelStyle? label;

  /// The stroke style of the tick grid line.
  StrokeStyle? grid;

  /// Whether this tick has a label to render.
  bool get haveLabel => label != null && text != null && text!.isNotEmpty;
}

/// The operator to create tick informations.
///
/// The tick informations are use by both [AxisRenderOp] and [GridRenderOp].
class TickInfoOp extends Operator<List<TickInfo>> {
  TickInfoOp(Map<String, dynamic> params) : super(params);

  @override
  List<TickInfo> evaluate() {
    final variable = params['variable'] as String;
    final scales = params['scales'] as Map<String, ScaleConv>;
    final tickLine = params['tickLine'] as TickLine?;
    final tickLineMapper = params['tickLineMapper'] as TickLineMapper?;
    final label = params['label'] as LabelStyle?;
    final labelMapper = params['labelMapper'] as LabelMapper?;
    final grid = params['grid'] as StrokeStyle?;
    final gridMapper = params['gridMapper'] as GridMapper?;

    final scale = scales[variable]!;

    final ticks = scale.ticks
        .map((value) => TickInfo(
              scale.normalize(scale.convert(value)),
              scale.format(value),
            ))
        .toList();

    final total = ticks.length;
    for (var i = 0; i < total; i++) {
      final tick = ticks[i];
      if (tickLine != null) {
        tick.tickLine = tickLine;
      } else if (tickLineMapper != null) {
        tick.tickLine = tickLineMapper(tick.text, i, total);
      }
      if (label != null) {
        tick.label = label;
      } else if (labelMapper != null) {
        tick.label = labelMapper(tick.text, i, total);
      }
      if (grid != null) {
        tick.grid = grid;
      } else if (gridMapper != null) {
        tick.grid = gridMapper(tick.text, i, total);
      }
    }

    return ticks;
  }
}

/// The axis scene.
class AxisScene extends Scene {
  AxisScene(int layer) : super(layer);

  @override
  int get intrinsicLayer => IntrinsicLayers.axis;
}

/// The axis render operator.
class AxisRenderOp extends Render<AxisScene> {
  AxisRenderOp(
    Map<String, dynamic> params,
    AxisScene scene,
    GraphicView view,
  ) : super(params, scene, view);

  @override
  void render() {
    final coord = params['coord'] as CoordConv;
    final dim = params['dim'] as Dim;
    final position = params['position'] as double;
    final flip = params['flip'] as bool;
    final line = params['line'] as StrokeStyle?;
    final ticks = params['ticks'] as List<TickInfo>;

    final canvasDim = coord.getCanvasDim(dim);
    if (coord is RectCoordConv) {
      if (canvasDim == Dim.x) {
        scene.figures = renderHorizontalAxis(
          ticks,
          position,
          flip,
          line,
          coord,
        );
      } else {
        scene.figures = renderVerticalAxis(
          ticks,
          position,
          flip,
          line,
          coord,
        );
      }
    } else {
      coord as PolarCoordConv;
      if (canvasDim == Dim.x) {
        scene.figures = renderCircularAxis(
          ticks,
          position,
          flip,
          line,
          coord,
        );
      } else {
        scene.figures = renderRadialAxis(
          ticks,
          position,
          flip,
          line,
          coord,
        );
      }
    }
  }
}

/// The axis grid scene.
class GridScene extends Scene {
  GridScene(int layer) : super(layer);

  @override
  int get intrinsicLayer => IntrinsicLayers.grid;
}

/// The axis grid render operator.
class GridRenderOp extends Render<GridScene> {
  GridRenderOp(Map<String, dynamic> params, GridScene scene, GraphicView view)
      : super(params, scene, view);

  @override
  void render() {
    final coord = params['coord'] as CoordConv;
    final dim = params['dim'] as Dim;
    final ticks = params['ticks'] as List<TickInfo>;

    final canvasDim = coord.getCanvasDim(dim);
    if (coord is RectCoordConv) {
      if (canvasDim == Dim.x) {
        scene.figures = renderHorizontalGrid(
          ticks,
          coord,
        );
      } else {
        scene.figures = renderVerticalGrid(
          ticks,
          coord,
        );
      }
    } else {
      coord as PolarCoordConv;
      if (canvasDim == Dim.x) {
        scene.figures = renderCircularGrid(
          ticks,
          coord,
        );
      } else {
        scene.figures = renderRadialGrid(
          ticks,
          coord,
        );
      }
    }
  }
}
