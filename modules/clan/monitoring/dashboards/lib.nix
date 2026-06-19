let
  prometheus = {
    type = "prometheus";
    uid = "prometheus";
  };

  loki = {
    type = "loki";
    uid = "loki";
  };

  grafana = {
    type = "grafana";
    uid = "-- Grafana --";
  };

  thresholds = {
    neutral = {
      mode = "absolute";
      steps = [
        {
          color = "blue";
          value = null;
        }
      ];
    };

    goodWhenZero = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "red";
          value = 1;
        }
      ];
    };

    goodWhenOne = {
      mode = "absolute";
      steps = [
        {
          color = "red";
          value = null;
        }
        {
          color = "green";
          value = 1;
        }
      ];
    };

    pressure = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 70;
        }
        {
          color = "red";
          value = 90;
        }
      ];
    };

    ioPressure = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 10;
        }
        {
          color = "red";
          value = 25;
        }
      ];
    };

    temperatureC = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 70;
        }
        {
          color = "red";
          value = 85;
        }
      ];
    };

    networkDeviceTemperatureC = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 65;
        }
        {
          color = "red";
          value = 75;
        }
      ];
    };

    linkSpeedBps = {
      mode = "absolute";
      steps = [
        {
          color = "red";
          value = null;
        }
        {
          color = "green";
          value = 1000000000;
        }
        {
          color = "blue";
          value = 10000000000;
        }
      ];
    };

    latencyMs = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 40;
        }
        {
          color = "red";
          value = 100;
        }
      ];
    };

    packetLoss = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 0.01;
        }
        {
          color = "red";
          value = 0.05;
        }
      ];
    };

    packetLossPercent = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 1;
        }
        {
          color = "red";
          value = 5;
        }
      ];
    };
  };

  mappings = {
    upDown = [
      {
        type = "value";
        options = {
          "0" = {
            color = "red";
            text = "down";
          };
          "1" = {
            color = "green";
            text = "up";
          };
        };
      }
    ];
  };

  target = refId: expr: legendFormat: {
    datasource = prometheus;
    editorMode = "code";
    inherit expr legendFormat refId;
    range = true;
  };

  instantTarget =
    refId: expr: legendFormat:
    (target refId expr legendFormat)
    // {
      instant = true;
      range = false;
    };

  lokiTarget = refId: expr: {
    datasource = loki;
    editorMode = "code";
    inherit expr refId;
    queryType = "range";
  };

  colorOverride = name: color: {
    matcher = {
      id = "byName";
      options = name;
    };
    properties = [
      {
        id = "color";
        value = {
          fixedColor = color;
          mode = "fixed";
        };
      }
    ];
  };

  grid = x: y: w: h: {
    inherit
      x
      y
      w
      h
      ;
  };

  baseFieldConfig =
    {
      unit,
      threshold,
      valueMappings ? [ ],
      overrides ? [ ],
      fixedColor ? null,
    }:
    {
      defaults = {
        color =
          if fixedColor == null then
            {
              mode = "thresholds";
            }
          else
            {
              inherit fixedColor;
              mode = "fixed";
            };
        mappings = valueMappings;
        thresholds = threshold;
        inherit unit;
      };
      inherit overrides;
    };

  stat =
    {
      id,
      title,
      x,
      y,
      w,
      h,
      expr,
      unit ? "short",
      threshold ? thresholds.goodWhenZero,
      valueMappings ? [ ],
      fixedColor ? null,
      sparkline ? false,
    }:
    {
      inherit id title;
      type = "stat";
      datasource = prometheus;
      gridPos = grid x y w h;
      targets = [ ((if sparkline then target else instantTarget) "A" expr "") ];
      fieldConfig = baseFieldConfig {
        inherit
          fixedColor
          threshold
          unit
          valueMappings
          ;
      };
      options = {
        colorMode = "value";
        graphMode = if sparkline then "area" else "none";
        justifyMode = "center";
        orientation = "auto";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        textMode = "auto";
        wideLayout = true;
      };
    };

  statTargets =
    {
      id,
      title,
      x,
      y,
      w,
      h,
      targets,
      unit ? "short",
      threshold ? thresholds.neutral,
      valueMappings ? [ ],
      overrides ? [ ],
      fixedColor ? null,
    }:
    {
      inherit id targets title;
      type = "stat";
      datasource = prometheus;
      gridPos = grid x y w h;
      fieldConfig = baseFieldConfig {
        inherit
          fixedColor
          overrides
          threshold
          unit
          valueMappings
          ;
      };
      options = {
        colorMode = "value";
        graphMode = "none";
        justifyMode = "center";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        textMode = "auto";
        wideLayout = true;
      };
    };

  timeseries =
    {
      id,
      title,
      x,
      y,
      w,
      h,
      targets,
      unit ? "short",
      threshold ? thresholds.pressure,
      overrides ? [ ],
      legend ? true,
      fillOpacity ? 0,
    }:
    {
      inherit id title targets;
      type = "timeseries";
      datasource = prometheus;
      gridPos = grid x y w h;
      fieldConfig =
        (baseFieldConfig {
          inherit overrides threshold unit;
        })
        // {
          defaults =
            (baseFieldConfig {
              inherit threshold unit;
            }).defaults
            // {
              custom = {
                drawStyle = "line";
                inherit fillOpacity;
                lineInterpolation = "smooth";
                lineWidth = 1;
                pointSize = 4;
                showPoints = "never";
                spanNulls = true;
                stacking.mode = "none";
                thresholdsStyle.mode = "off";
              };
            };
        };
      options = {
        legend = {
          calcs = [ "lastNotNull" ];
          displayMode = "list";
          placement = "bottom";
          showLegend = legend;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
    };

  barGauge =
    {
      id,
      title,
      x,
      y,
      w,
      h,
      targets,
      unit ? "short",
      threshold ? thresholds.pressure,
      valueMappings ? [ ],
      overrides ? [ ],
      fixedColor ? null,
      displayMode ? "gradient",
    }:
    {
      inherit id title targets;
      type = "bargauge";
      datasource = prometheus;
      gridPos = grid x y w h;
      fieldConfig = baseFieldConfig {
        inherit
          fixedColor
          overrides
          threshold
          unit
          valueMappings
          ;
      };
      options = {
        inherit displayMode;
        maxVizHeight = 300;
        minVizHeight = 16;
        minVizWidth = 8;
        namePlacement = "auto";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        showUnfilled = true;
        sizing = "auto";
        valueMode = "color";
      };
    };

  row =
    {
      id,
      title,
      y,
      collapsed ? true,
      panels ? [ ],
    }:
    {
      inherit collapsed id title;
      type = "row";
      gridPos = grid 0 y 24 1;
      panels = if collapsed then panels else [ ];
    };

  text =
    {
      id,
      title,
      x,
      y,
      w,
      h,
      content,
    }:
    {
      inherit id title;
      type = "text";
      datasource = grafana;
      gridPos = grid x y w h;
      options = {
        inherit content;
        mode = "markdown";
      };
    };

  logs =
    {
      id,
      title,
      x,
      y,
      w,
      h,
      expr,
    }:
    {
      inherit id title;
      type = "logs";
      datasource = loki;
      gridPos = grid x y w h;
      targets = [ (lokiTarget "A" expr) ];
      options = {
        dedupStrategy = "none";
        enableLogDetails = true;
        prettifyLogMessage = false;
        showCommonLabels = false;
        showLabels = false;
        showTime = true;
        sortOrder = "Descending";
        wrapLogMessage = true;
      };
    };

  dashboard =
    {
      uid,
      title,
      panels,
      timeFrom ? "now-6h",
      refresh ? "30s",
    }:
    {
      annotations.list = [ ];
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      inherit
        panels
        refresh
        title
        uid
        ;
      schemaVersion = 41;
      tags = [ "atlas" ];
      templating.list = [ ];
      time = {
        from = timeFrom;
        to = "now";
      };
      timezone = "browser";
      version = 1;
      weekStart = "";
    };
in
{
  inherit
    barGauge
    colorOverride
    dashboard
    instantTarget
    loki
    lokiTarget
    logs
    mappings
    prometheus
    row
    stat
    statTargets
    target
    text
    thresholds
    timeseries
    ;
}
