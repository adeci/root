let
  prometheus = {
    type = "prometheus";
    uid = "prometheus";
  };

  loki = {
    type = "loki";
    uid = "loki";
  };

  # A strip's colours: the idle shade, then a brighter one from each step's value up.
  shades = steps: {
    mode = "absolute";
    steps = [ (shade null "#1e2128") ] ++ steps;
  };
  shade = value: color: { inherit color value; };

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

    # An SSD's rated endurance used, in percent.
    wear = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 80;
        }
      ];
    };

    # macOS's memory pressure level: 1 normal, 2 warning, 4 critical.
    memoryPressureLevel = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "yellow";
          value = 2;
        }
        {
          color = "red";
          value = 4;
        }
      ];
    };

    # The worst alert firing on a machine: 1 a warning, 2 critical.
    alertSeverity = {
      mode = "absolute";
      steps = [
        {
          color = "yellow";
          value = null;
        }
        {
          color = "red";
          value = 2;
        }
      ];
    };

    cpuShades = shades [
      (shade 5 "#24406e")
      (shade 15 "#2f5fa8")
      (shade 35 "#4a8fe0")
      (shade 60 "#8cc6fb")
      (shade 85 "#e4f4ff")
    ];

    pressureShades = shades [
      (shade 1 "#5a3e15")
      (shade 3 "#8d5d18")
      (shade 10 "#c58527")
      (shade 25 "#f0bd68")
      (shade 50 "#fff2cf")
    ];

    diskShades = shades [
      (shade 5 "#1d4a4b")
      (shade 15 "#27757a")
      (shade 35 "#3ba69d")
      (shade 60 "#7fd6c6")
      (shade 85 "#dcf7f0")
    ];

    # macOS's memory pressure level in the pressure shades: 2 warning, 4 critical.
    memoryPressureLevelShades = shades [
      (shade 2 "#c58527")
      (shade 4 "#fff2cf")
    ];
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

    # 0 and 1 as a dot, which the column's thresholds colour.
    dot = [
      {
        type = "value";
        options = {
          "0".text = "●";
          "1".text = "●";
        };
      }
    ];

    # Nothing to see at zero, so only a value above it stands out.
    blankZero = [
      {
        type = "value";
        options."0".text = "";
      }
    ];

    # A kernel waiting for a reboot; nothing to see otherwise.
    rebootNeeded = [
      {
        type = "value";
        options = {
          "0".text = "";
          "1" = {
            color = "yellow";
            text = "needed";
          };
        };
      }
    ];

    # A drive's SMART self-assessment.
    passed = [
      {
        type = "value";
        options = {
          "0" = {
            color = "red";
            text = "failed";
          };
          "1" = {
            color = "green";
            text = "passed";
          };
        };
      }
    ];

    # macOS's memory pressure level, as Activity Monitor colours it.
    memoryPressureLevel = [
      {
        type = "value";
        options = {
          "1" = {
            color = "green";
            text = "normal";
          };
          "2" = {
            color = "yellow";
            text = "warning";
          };
          "4" = {
            color = "red";
            text = "critical";
          };
        };
      }
    ];

    # macOS's memory pressure level by name only, for a strip that colours it by its shades.
    memoryPressureLevelNames = [
      {
        type = "value";
        options = {
          "1".text = "normal";
          "2".text = "warning";
          "4".text = "critical";
        };
      }
    ];

    # The worst alert firing on a machine, by its severity.
    alertSeverity = [
      {
        type = "value";
        options = {
          "0".text = "";
          "1" = {
            color = "yellow";
            text = "warning";
          };
          "2" = {
            color = "red";
            text = "critical";
          };
        };
      }
    ];

    # An alert's severity label in its colour.
    severityColours = [
      {
        type = "value";
        options = {
          warning.color = "yellow";
          critical.color = "red";
        };
      }
    ];

    # 1 marks a message seen in the last day but not the day before.
    newMessage = [
      {
        type = "value";
        options."1".text = "new";
      }
    ];
  };

  target = expr: legendFormat: {
    datasource = prometheus;
    editorMode = "code";
    inherit expr legendFormat;
    range = true;
  };

  lokiTarget = expr: legendFormat: {
    datasource = loki;
    editorMode = "code";
    inherit expr legendFormat;
    queryType = "range";
  };

  instantTarget =
    expr: legendFormat:
    target expr legendFormat
    // {
      instant = true;
      range = false;
    };

  # An instant query whose result Grafana shows as a table: Loki's always is, Prometheus's when asked.
  tableTarget =
    datasource: expr:
    if datasource == loki then
      lokiTarget expr "" // { queryType = "instant"; }
    else
      instantTarget expr "" // { format = "table"; };

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

  # Colours the series whose names match a regex, e.g. every series of one machine.
  colorOverrideMatching = regex: color: {
    matcher = {
      id = "byRegexp";
      options = regex;
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

  queryOverride =
    refId:
    {
      unit,
      threshold,
      valueMappings,
    }:
    {
      matcher = {
        id = "byFrameRefID";
        options = refId;
      };
      properties = [
        (property "unit" unit)
        (property "thresholds" threshold)
        (property "mappings" valueMappings)
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
      overrides ? [ ],
      # A variable whose every selected value gets its own copy of the panel, side by side.
      repeat ? null,
      # The shortest step between points, e.g. "5m" to average a jittery reading.
      interval ? null,
      stackedBars ? false,
      datasource ? prometheus,
    }:
    {
      inherit title datasource;
      type = "timeseries";
      gridPos = { inherit w h; };
      targets = lettered targets;
      fieldConfig = {
        defaults = {
          # A series' colour follows its name, so a machine has the same one on every panel.
          color.mode = "palette-classic-by-name";
          inherit unit;
        }
        # Percentages start at 0, so a steady 10 % doesn't fill the panel.
        // (if unit == "percent" || unit == "percentunit" then { min = 0; } else { })
        // {
          custom = {
            drawStyle = "line";
            fillOpacity = 0;
            lineInterpolation = "linear";
            lineWidth = 1;
            pointSize = 4;
            showPoints = "never";
            # Bridges a missed scrape or two at 30 s, not a machine that was asleep or off.
            spanNulls = 60000;
            stacking.mode = "none";
            thresholdsStyle.mode = "off";
          }
          // (
            if stackedBars then
              {
                drawStyle = "bars";
                fillOpacity = 80;
                stacking.mode = "normal";
              }
            else
              { }
          );
        };
        inherit overrides;
      };
      options = {
        legend = {
          calcs = [ ];
          displayMode = "list";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
    }
    // (
      if repeat == null then
        { }
      else
        {
          inherit repeat;
          repeatDirection = "h";
        }
    )
    // (if interval == null then { } else { inherit interval; });

  # One row per series, its value over time as threshold colours.
  statusHistory =
    {
      title,
      w,
      h,
      targets,
      threshold,
      description ? null,
      unit ? "short",
      overrides ? [ ],
    }:
    {
      inherit title;
      datasource = prometheus;
      type = "status-history";
      gridPos = { inherit w h; };
      targets = lettered targets;
      # A cell per point: a coarse step, each value the average over it, keeps the rows drawable.
      maxDataPoints = 150;
      interval = "5m";
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          thresholds = threshold;
          mappings = [ ];
          inherit unit;
          # Borderless cells join into continuous bars.
          custom = {
            fillOpacity = 80;
            lineWidth = 0;
          };
        };
        inherit overrides;
      };
      options = {
        showValue = "never";
        rowHeight = 0.9;
        colWidth = 1;
        legend.showLegend = false;
        tooltip.mode = "single";
      };
    }
    // (if description == null then { } else { inherit description; });

  # One row per series, its state over time as the colours of its value mappings.
  stateTimeline =
    {
      title,
      w,
      h,
      targets,
      valueMappings,
      threshold,
    }:
    {
      inherit title;
      type = "state-timeline";
      datasource = prometheus;
      gridPos = { inherit w h; };
      targets = lettered targets;
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          thresholds = threshold;
          mappings = valueMappings;
          custom = {
            fillOpacity = 80;
            lineWidth = 0;
            # A gap of more than a missed scrape or two shows as no data.
            insertNulls = 60000;
            spanNulls = false;
          };
        };
        overrides = [ ];
      };
      options = {
        mergeValues = true;
        showValue = "never";
        rowHeight = 0.9;
        legend.showLegend = false;
        tooltip.mode = "single";
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

  # Hides, renames and orders a table's columns: `firstColumns` lead, in order, and the rest follow.
  organize =
    {
      hiddenColumns,
      renamedColumns,
      firstColumns,
    }:
    {
      id = "organize";
      options = {
        excludeByName = builtins.listToAttrs (
          map (name: {
            inherit name;
            value = true;
          }) hiddenColumns
        );
        renameByName = renamedColumns;
        indexByName = builtins.listToAttrs (
          builtins.genList (index: {
            name = builtins.elemAt firstColumns index;
            value = index;
          }) (builtins.length firstColumns)
        );
      };
    };

  # How a table column shows its values, all optional: `unit`, `decimals`, `width` in pixels, `threshold` or `colours` (value mappings) to colour the text, `valueMappings`, `noValue`, and a colour for a `bar` from 0 to 100 or a `sparkline` of the time range.
  columnOverride = column: {
    matcher = {
      id = "byName";
      options = column.name;
    };
    properties =
      (if column ? unit then [ (property "unit" column.unit) ] else [ ])
      ++ (if column ? decimals then [ (property "decimals" column.decimals) ] else [ ])
      ++ (if column ? width then [ (property "custom.width" column.width) ] else [ ])
      ++ (
        if column ? threshold then
          [
            (property "thresholds" column.threshold)
            (property "custom.cellOptions" { type = "color-text"; })
          ]
        else
          [ ]
      )
      ++ (if column ? valueMappings then [ (property "mappings" column.valueMappings) ] else [ ])
      ++ (
        if column ? colours then
          [
            (property "mappings" column.colours)
            (property "custom.cellOptions" { type = "color-text"; })
          ]
        else
          [ ]
      )
      ++ (if column ? noValue then [ (property "noValue" column.noValue) ] else [ ])
      ++ (
        if column ? bar then
          [
            (property "min" 0)
            (property "max" 100)
            (property "color" {
              mode = "fixed";
              fixedColor = column.bar;
            })
            (property "custom.cellOptions" {
              type = "gauge";
              mode = "gradient";
              valueDisplayMode = "text";
            })
          ]
        else
          [ ]
      )
      ++ (
        if column ? sparkline then
          [
            (property "color" {
              mode = "fixed";
              fixedColor = column.sparkline;
            })
            (property "custom.cellOptions" {
              type = "sparkline";
              fillOpacity = 25;
              gradientMode = "opacity";
              spanNulls = true;
            })
          ]
        else
          [ ]
      );
  };
  property = id: value: { inherit id value; };

  # One row per label set the queries share, one column per query; `renamedColumns` names the label columns.
  # A sparkline column's query runs over the time range; a column with `hidden = true` only brings its rows.
  mergedTable =
    {
      title,
      w,
      h,
      columns,
      description ? null,
      hiddenColumns ? [ ],
      renamedColumns ? { },
      firstColumns ? [ ],
      # How label columns show, by the name shown and as for `columns`, e.g. { Host.width = 85; }.
      labelColumns ? { },
      # Columns to sort the rows by, first one first, e.g. [ { displayName = "Host"; desc = false; } ].
      sortBy ? [ ],
      # Joins the queries' rows on this label in place of merging them, as a sparkline needs: beside its trend, an empty query stops a merge.
      joinBy ? null,
      # Shown in place of the table while no query returns anything.
      noDataText ? null,
      datasource ? prometheus,
    }:
    let
      targets = lettered (
        map (
          column: if column ? sparkline then target column.expr "" else tableTarget datasource column.expr
        ) columns
      );
      # Each column with its refId and the field Grafana gives its values: "Trend #A" for a sparkline, else "Value #A", or just "Value" for a lone Prometheus query.
      queryColumns = builtins.genList (
        index:
        let
          column = builtins.elemAt columns index;
          inherit (builtins.elemAt targets index) refId;
        in
        column
        // {
          inherit refId;
          field =
            if column ? sparkline then
              "Trend #${refId}"
            else if datasource == prometheus && builtins.length columns == 1 then
              "Value"
            else
              "Value #${refId}";
        }
        # The empty text is for an empty table, not for each empty cell.
        // (if noDataText == null then { } else { noValue = " "; })
      ) (builtins.length columns);
      sparklines = builtins.filter (column: column ? sparkline) queryColumns;
      fields = map (column: column.field);
      hiddenFields = [ "Time" ] ++ hiddenColumns;
      hiddenQueries = builtins.filter (column: column.hidden or false) queryColumns;
    in
    {
      inherit title targets datasource;
      type = "table";
      gridPos = { inherit w h; };
      fieldConfig = {
        # Narrow enough that a dozen columns fit across the page.
        defaults = {
          custom.minWidth = 80;
        }
        // (if noDataText == null then { } else { noValue = noDataText; });
        overrides =
          map columnOverride queryColumns
          ++ map (name: columnOverride (labelColumns.${name} // { inherit name; })) (
            builtins.attrNames labelColumns
          );
      };
      options = {
        cellHeight = "sm";
        showHeader = true;
        inherit sortBy;
      };
      transformations =
        # Limited to its own query: otherwise it makes a trend of every single-row result too.
        map (column: {
          id = "timeSeriesTable";
          options.${column.refId}.stat = "max";
          filter = {
            id = "byRefId";
            options = column.refId;
          };
        }) sparklines
        ++ (
          if joinBy == null then
            [
              {
                id = "merge";
                options = { };
              }
            ]
          else
            [
              {
                id = "joinByField";
                options = {
                  byField = joinBy;
                  mode = "outerTabular";
                };
              }
              # The join repeats each query's other fields as "Time 1", "os 2" and so on.
              {
                id = "filterFieldsByName";
                options.exclude.pattern = "/^(${builtins.concatStringsSep "|" hiddenFields})( \\d+)?$/";
              }
            ]
        )
        ++ [
          (organize {
            hiddenColumns = hiddenFields ++ fields hiddenQueries;
            renamedColumns =
              renamedColumns
              // builtins.listToAttrs (
                map (column: {
                  name = column.field;
                  value = column.name;
                }) queryColumns
              );
            # A sparkline's frame leads the others, so the query columns are put in their order too.
            firstColumns = if firstColumns == [ ] then [ ] else firstColumns ++ fields queryColumns;
          })
        ];
    }
    # A sparkline has no use for more points than this.
    // (if sparklines == [ ] then { } else { maxDataPoints = 120; })
    // (if description == null then { } else { inherit description; });

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
      targets = lettered [ (lokiTarget expr "") ];
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

  # A multi-select picker over a label's values, all of them at first; queries match it as `label=~"$name"`.
  labelVariable =
    {
      name,
      label,
      query,
      # What "All" matches; null keeps Grafana's list of the current values.
      allValue ? null,
      # 1 sorts the values alphabetically, 2 in reverse.
      sort ? 1,
    }:
    {
      inherit
        name
        label
        query
        allValue
        sort
        ;
      type = "query";
      datasource = prometheus;
      definition = query;
      refresh = 1;
      multi = true;
      includeAll = true;
      current = {
        text = "All";
        value = "$__all";
      };
    };

  # `panels` are either all rows or no rows.
  dashboard =
    {
      uid,
      title,
      panels,
      variables ? [ ],
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
      templating.list = variables;
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
    colorOverrideMatching
    dashboard
    labelVariable
    logs
    loki
    lokiTarget
    mappings
    mergedTable
    queryOverride
    row
    stat
    stateTimeline
    statTargets
    statusHistory
    target
    thresholds
    timeseries
    ;
}
