let
  prometheus = {
    type = "prometheus";
    uid = "prometheus";
  };

  loki = {
    type = "loki";
    uid = "loki";
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

    cautionWhenNonZero = {
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

  target = expr: legendFormat: {
    datasource = prometheus;
    editorMode = "code";
    inherit expr legendFormat;
    range = true;
  };

  instantTarget =
    expr: legendFormat:
    target expr legendFormat
    // {
      instant = true;
      range = false;
    };

  tableTarget = expr: instantTarget expr "" // { format = "table"; };

  # A panel's queries are named A, B, C… in order.
  lettered =
    targets:
    builtins.genList (
      index:
      builtins.elemAt targets index
      // {
        refId = builtins.substring index 1 "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
      }
    ) (builtins.length targets);

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

  # Panels give only their size; `dashboard` places them.

  stat =
    {
      title,
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
      inherit title;
      type = "stat";
      datasource = prometheus;
      gridPos = { inherit w h; };
      targets = lettered [ ((if sparkline then target else instantTarget) expr "") ];
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
      title,
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
      inherit title;
      type = "stat";
      datasource = prometheus;
      gridPos = { inherit w h; };
      targets = lettered targets;
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
      title,
      w,
      h,
      targets,
      unit ? "short",
      threshold ? thresholds.pressure,
      overrides ? [ ],
    }:
    {
      inherit title;
      type = "timeseries";
      datasource = prometheus;
      gridPos = { inherit w h; };
      targets = lettered targets;
      fieldConfig =
        baseFieldConfig {
          inherit overrides threshold unit;
        }
        // {
          defaults =
            (baseFieldConfig {
              inherit threshold unit;
            }).defaults
            // {
              custom = {
                drawStyle = "line";
                fillOpacity = 0;
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
          showLegend = true;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
    };

  barGauge =
    {
      title,
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
      inherit title;
      type = "bargauge";
      datasource = prometheus;
      gridPos = { inherit w h; };
      targets = lettered targets;
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

  table =
    {
      title,
      w,
      h,
      targets,
      hiddenColumns ? [ ],
    }:
    {
      inherit title;
      type = "table";
      datasource = prometheus;
      gridPos = { inherit w h; };
      targets = lettered targets;
      fieldConfig = {
        defaults = { };
        overrides = [ ];
      };
      options = {
        cellHeight = "sm";
        showHeader = true;
      };
      transformations = [
        {
          id = "organize";
          options.excludeByName = builtins.listToAttrs (
            map (name: {
              inherit name;
              value = true;
            }) hiddenColumns
          );
        }
      ];
    };

  logs =
    {
      title,
      w,
      h,
      expr,
    }:
    {
      inherit title;
      type = "logs";
      datasource = loki;
      gridPos = { inherit w h; };
      targets = lettered [
        {
          datasource = loki;
          editorMode = "code";
          inherit expr;
          queryType = "range";
        }
      ];
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

  # A section of the page; collapsed, it shows only its title until opened.
  row =
    {
      title,
      panels,
      collapsed ? true,
    }:
    {
      inherit collapsed panels title;
      type = "row";
    };

  # Panels go left to right on the 24-wide grid, wrapping onto a new line as tall as its tallest panel.
  flow =
    top:
    let
      place =
        line: panel:
        let
          inherit (panel.gridPos) w h;
          wraps = line.x + w > 24;
          x = if wraps then 0 else line.x;
          y = if wraps then line.bottom else line.y;
        in
        {
          inherit y;
          x = x + w;
          bottom = if y + h > line.bottom then y + h else line.bottom;
          panels = line.panels ++ [
            (
              panel
              // {
                gridPos = panel.gridPos // {
                  inherit x y;
                };
              }
            )
          ];
        };
    in
    builtins.foldl' place {
      x = 0;
      y = top;
      bottom = top;
      panels = [ ];
    };

  # Rows stack down the page; Grafana keeps a collapsed row's panels inside it and an open row's after it.
  stack =
    let
      addRow =
        page: row:
        let
          content = flow (page.bottom + 1) row.panels;
          header = row // {
            gridPos = {
              x = 0;
              y = page.bottom;
              w = 24;
              h = 1;
            };
            panels = if row.collapsed then content.panels else [ ];
          };
        in
        {
          inherit (content) bottom;
          panels = page.panels ++ [ header ] ++ (if row.collapsed then [ ] else content.panels);
        };
    in
    rows:
    (builtins.foldl' addRow {
      bottom = 0;
      panels = [ ];
    } rows).panels;

  # Panel ids count down the page from 1, the panels inside collapsed rows included.
  number =
    let
      numberFrom =
        first: panels:
        builtins.genList (index: builtins.elemAt panels index // { id = first + index; }) (
          builtins.length panels
        );
      addPanel =
        numbered: panel:
        let
          id = numbered.next;
          inside = panel.panels or [ ];
        in
        {
          next = id + 1 + builtins.length inside;
          panels = numbered.panels ++ [
            (
              panel
              // {
                inherit id;
              }
              // (if panel ? panels then { panels = numberFrom (id + 1) inside; } else { })
            )
          ];
        };
    in
    panels:
    (builtins.foldl' addPanel {
      next = 1;
      panels = [ ];
    } panels).panels;

  # `panels` are either all rows or no rows.
  dashboard =
    {
      uid,
      title,
      panels,
    }:
    {
      annotations.list = [ ];
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      panels = number (
        if builtins.all (panel: panel.type == "row") panels then stack panels else (flow 0 panels).panels
      );
      refresh = "30s";
      inherit title uid;
      schemaVersion = 41;
      tags = [ "monitoring" ];
      templating.list = [ ];
      time = {
        from = "now-6h";
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
    logs
    mappings
    row
    stat
    statTargets
    table
    tableTarget
    target
    thresholds
    timeseries
    ;
}
