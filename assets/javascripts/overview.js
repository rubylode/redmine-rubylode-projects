/* Rubylode Projects: the tooltips and popovers of a project's Overview and of the projects list.
 * Copyright (C) 2026  Nick Gorbikoff. GPL v2 or later, as the rest of the plugin.
 *
 * Plain JavaScript, no framework. Everything shown comes from the JSON block the server renders into the page
 * (script[data-rubylode-overview-data]), so there are no requests, and it is written out with textContent, never as HTML.
 * Without this file the page still works: the chart's weeks, the tiles and the bars are ordinary links.
 *
 * The Overview page has the block inside its [data-rubylode-projects="overview"] wrapper. The projects list has the summary in
 * [data-rubylode-projects="summary"] (which may be missing: ?summary=0) and the block after the list, and the sparklines in the
 * list's cells.
 */
(function () {
  "use strict";

  var dataElement = document.querySelector("script[data-rubylode-overview-data]");
  var root = document.querySelector("[data-rubylode-projects]");
  if (!dataElement) { return; }

  var data;
  try {
    data = JSON.parse(dataElement.textContent);
  } catch (error) {
    return;
  }
  var strings = data.strings;
  var HIDE_DELAY_MILLISECONDS = 160;
  var openPopover = null;

  function element(tagName, className, text) {
    var node = document.createElement(tagName);
    if (className) { node.className = className; }
    if (text !== undefined && text !== null) { node.textContent = String(text); }
    return node;
  }

  // The server sends paths only; anything else is not made into a link.
  function pathLink(className, text, path) {
    var link = element("a", className, text);
    if (typeof path === "string" && path.charAt(0) === "/" && path.charAt(1) !== "/") { link.setAttribute("href", path); }
    return link;
  }

  function signed(number) { return number > 0 ? "+" + number : String(number); }

  function figureRow(label, value) {
    var row = element("div", "rubylode-overview-tooltip-row");
    row.appendChild(element("dt", null, label));
    row.appendChild(element("dd", null, value));
    return row;
  }

  // A card that appears beside its host. Opens on hover, focus and the first tap; closes on leave, blur and Escape.
  function Popover(host, className, role) {
    var self = this;
    this.host = host;
    this.node = element("div", "rubylode-overview-tooltip " + className);
    this.node.setAttribute("role", role);
    this.node.hidden = true;
    this.hideTimer = null;
    this.onClose = null;
    this.returnFocusTo = null;
    this.keepOpenWhile = function () { return false; };
    this.cancelHide = function () { window.clearTimeout(self.hideTimer); };
    this.hideSoon = function () {
      self.cancelHide();
      self.hideTimer = window.setTimeout(function () {
        if (!self.keepOpenWhile()) { self.close(); }
      }, HIDE_DELAY_MILLISECONDS);
    };
    this.node.addEventListener("mouseenter", this.cancelHide);
    this.node.addEventListener("mouseleave", this.hideSoon);
    this.node.addEventListener("focusin", this.cancelHide);
    this.node.addEventListener("focusout", function (event) {
      if (!self.node.contains(event.relatedTarget) && !self.host.contains(event.relatedTarget)) { self.hideSoon(); }
    });
  }

  Popover.prototype.show = function (fill, place) {
    if (openPopover && openPopover !== this) { openPopover.close(); }
    this.cancelHide();
    while (this.node.firstChild) { this.node.removeChild(this.node.firstChild); }
    fill(this.node);
    this.node.hidden = false;
    place(this.node);
    openPopover = this;
  };

  Popover.prototype.close = function () {
    this.cancelHide();
    if (this.node.hidden) { return; }
    this.node.hidden = true;
    if (openPopover === this) { openPopover = null; }
    if (this.onClose) { this.onClose(); }
  };

  Popover.prototype.isOpen = function () { return !this.node.hidden; };

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape" || !openPopover) { return; }
    var popover = openPopover;
    var focusInside = popover.node.contains(document.activeElement);
    var anchor = popover.returnFocusTo ? popover.returnFocusTo() : popover.host.querySelector("a[href]");
    popover.close();
    if (focusInside && anchor) { anchor.focus(); }
  });

  // On a touch screen the first tap shows the card and the second follows the link.
  // Called with the link and a function that says whether the card for it is open, from its pointerdown and click.
  function tapShowsCardFirst(link, isShown, show) {
    var previewing = false;
    link.addEventListener("pointerdown", function (event) {
      previewing = event.pointerType === "touch" && !isShown();
    });
    link.addEventListener("click", function (event) {
      if (!previewing) { return; }
      previewing = false;
      event.preventDefault();
      show();
    });
  }

  // ---- The weekly chart

  var chart = root && root.querySelector("[data-rubylode-chart]");
  if (chart && data.weeks) { setUpChart(chart, data.weeks); }

  function setUpChart(chartCard, weeks) {
    var weekLinks = Array.prototype.slice.call(chartCard.querySelectorAll("a.rubylode-overview-week"));
    var popover = new Popover(chartCard, "rubylode-overview-week-tooltip", "tooltip");
    var activeLink = null;
    chartCard.appendChild(popover.node);

    function clearHighlight() {
      chartCard.classList.remove("is-previewing");
      if (activeLink) { activeLink.classList.remove("is-active"); activeLink.removeAttribute("aria-describedby"); }
      activeLink = null;
    }
    popover.onClose = clearHighlight;
    popover.returnFocusTo = function () { return activeLink; };
    popover.keepOpenWhile = function () {
      return popover.node.contains(document.activeElement) || (activeLink !== null && activeLink === document.activeElement);
    };

    function fillWeek(week) {
      return function (node) {
        node.appendChild(element("div", "rubylode-overview-tooltip-title", week.label));
        var figures = element("dl", "rubylode-overview-tooltip-figures");
        figures.appendChild(figureRow(strings.opened, week.opened));
        figures.appendChild(figureRow(strings.closed, week.closed));
        figures.appendChild(figureRow(strings.net, signed(week.net)));
        figures.appendChild(figureRow(strings.openTotal, week.openTotal));
        node.appendChild(figures);
        if (week.topTrackers.length > 0) {
          node.appendChild(element("div", "rubylode-overview-tooltip-heading", strings.topTrackers));
          var list = element("ul", "rubylode-overview-tooltip-list");
          week.topTrackers.forEach(function (tracker) {
            list.appendChild(element("li", null, tracker.name + " " + tracker.count));
          });
          node.appendChild(list);
        }
        var links = element("div", "rubylode-overview-tooltip-links");
        links.appendChild(pathLink(null, strings.openedLink, week.openedUrl));
        links.appendChild(pathLink(null, strings.closedLink, week.closedUrl));
        node.appendChild(links);
      };
    }

    // Beside the week's column, on the side that has room, level with the top of the plot.
    function placeBeside(link) {
      return function (node) {
        var cardRect = chartCard.getBoundingClientRect();
        var columnRect = link.getBoundingClientRect();
        var gap = 8;
        var left = columnRect.right - cardRect.left + gap;
        if (left + node.offsetWidth > cardRect.width - 4) { left = columnRect.left - cardRect.left - node.offsetWidth - gap; }
        node.style.left = Math.max(4, left) + "px";
        node.style.top = Math.max(4, columnRect.top - cardRect.top + 12) + "px";
      };
    }

    function showWeek(link) {
      var week = weeks[Number(link.getAttribute("data-week-index"))];
      if (!week) { return; }
      if (activeLink && activeLink !== link) { activeLink.classList.remove("is-active"); activeLink.removeAttribute("aria-describedby"); }
      activeLink = link;
      popover.node.id = "rubylode-overview-week-tooltip";
      link.setAttribute("aria-describedby", popover.node.id);
      chartCard.classList.add("is-previewing");
      link.classList.add("is-active");
      popover.show(fillWeek(week), placeBeside(link));
    }

    weekLinks.forEach(function (link, index) {
      link.addEventListener("mouseenter", function () { showWeek(link); });
      link.addEventListener("focus", function () { showWeek(link); });
      link.addEventListener("mouseleave", popover.hideSoon);
      link.addEventListener("blur", function (event) {
        if (!popover.node.contains(event.relatedTarget)) { popover.hideSoon(); }
      });
      link.addEventListener("keydown", function (event) {
        if (event.altKey || event.ctrlKey || event.metaKey) { return; }
        var step = event.key === "ArrowRight" ? 1 : (event.key === "ArrowLeft" ? -1 : 0);
        if (step === 0) { return; }
        var neighbour = weekLinks[index + step];
        if (neighbour) { event.preventDefault(); neighbour.focus(); }
      });
      tapShowsCardFirst(link, function () { return popover.isOpen() && activeLink === link; }, function () { showWeek(link); });
    });

    Array.prototype.forEach.call(chartCard.querySelectorAll("button[data-series]"), function (button) {
      button.addEventListener("click", function () {
        var hidden = button.getAttribute("aria-pressed") === "true";
        button.setAttribute("aria-pressed", hidden ? "false" : "true");
        chartCard.classList.toggle("hides-" + button.getAttribute("data-series"), hidden);
      });
    });
  }

  // ---- The tiles and the tracker rows

  function setUpHost(host, link, className, role, fill) {
    var popover = new Popover(host, className, role);
    host.appendChild(popover.node);
    popover.keepOpenWhile = function () { return host.contains(document.activeElement); };

    function place(node) {
      node.style.left = "0";
      node.style.right = "auto";
      var rect = node.getBoundingClientRect();
      if (rect.right > document.documentElement.clientWidth - 8) {
        node.style.left = "auto";
        node.style.right = "0";
      }
    }
    function show() { popover.show(fill, place); }

    host.addEventListener("mouseenter", show);
    host.addEventListener("mouseleave", popover.hideSoon);
    host.addEventListener("focusin", show);
    host.addEventListener("focusout", function (event) {
      if (!host.contains(event.relatedTarget)) { popover.hideSoon(); }
    });
    if (link) { tapShowsCardFirst(link, function () { return popover.isOpen(); }, show); }
  }

  function fillTile(tile) {
    return function (node) {
      if (tile.seeAll) { node.setAttribute("aria-label", tile.seeAll); }
      var projects = tile.projects || [];
      var issues = tile.issues || [];
      if (issues.length === 0 && projects.length === 0) {
        node.appendChild(element("p", "rubylode-overview-tooltip-empty", tile.empty || strings.noIssues));
      } else if (projects.length > 0) {
        var projectList = element("ul", "rubylode-overview-tooltip-projects");
        projects.forEach(function (project) {
          var projectItem = element("li");
          projectItem.appendChild(pathLink("rubylode-overview-tooltip-issue-subject", project.name, project.url));
          projectItem.appendChild(element("span", "rubylode-overview-tooltip-issue-number", project.note));
          projectList.appendChild(projectItem);
        });
        node.appendChild(projectList);
      } else {
        var list = element("ul", "rubylode-overview-tooltip-issues");
        issues.forEach(function (issue) {
          var item = element("li");
          item.appendChild(element("span", "rubylode-overview-tooltip-issue-number", "#" + issue.id));
          var subject = pathLink("rubylode-overview-tooltip-issue-subject", issue.subject, issue.url);
          if (issue.project) { subject.setAttribute("title", issue.project + ": " + issue.subject); }
          item.appendChild(subject);
          item.appendChild(element("span", "rubylode-overview-chip rubylode-overview-tooltip-issue-status", issue.status));
          list.appendChild(item);
        });
        node.appendChild(list);
      }
      if (tile.url && tile.seeAll) { node.appendChild(pathLink("rubylode-overview-tooltip-see-all", tile.seeAll, tile.url)); }
    };
  }

  Array.prototype.forEach.call(root ? root.querySelectorAll("[data-rubylode-tile]") : [], function (tileElement) {
    var tile = data.tiles && data.tiles[tileElement.getAttribute("data-rubylode-tile")];
    if (!tile) { return; }
    setUpHost(tileElement, tileElement.querySelector(".rubylode-overview-tile-value a"), "rubylode-overview-tile-popover", "group", fillTile(tile));
  });

  function fillTracker(tracker) {
    return function (node) {
      node.appendChild(element("div", "rubylode-overview-tooltip-title", tracker.name));
      var figures = element("dl", "rubylode-overview-tooltip-figures");
      figures.appendChild(figureRow(strings.open, tracker.open));
      figures.appendChild(figureRow(strings.closed, tracker.closed));
      figures.appendChild(figureRow(strings.overdue, tracker.overdue));
      figures.appendChild(figureRow(strings.done, tracker.percentage + "%"));
      node.appendChild(figures);
    };
  }

  Array.prototype.forEach.call(root ? root.querySelectorAll("[data-rubylode-tracker]") : [], function (row) {
    var tracker = data.trackers && data.trackers[row.getAttribute("data-rubylode-tracker")];
    if (!tracker) { return; }
    setUpHost(row, row.querySelector("a.rubylode-overview-tracker-name"), "rubylode-overview-tracker-popover", "tooltip", fillTracker(tracker));
  });

  // ---- The bars of "Where the work is" on the projects list

  function fillBar(bar) {
    return function (node) {
      node.appendChild(element("div", "rubylode-overview-tooltip-title", bar.name));
      var figures = element("dl", "rubylode-overview-tooltip-figures");
      figures.appendChild(figureRow(strings.openIssues, bar.open));
      figures.appendChild(figureRow(strings.overdue, bar.overdue));
      figures.appendChild(figureRow(strings.closedWeek, bar.closedWeek));
      figures.appendChild(figureRow(strings.done, bar.percentage + "%"));
      node.appendChild(figures);
    };
  }

  Array.prototype.forEach.call(root ? root.querySelectorAll("[data-rubylode-bar]") : [], function (row) {
    var bar = data.bars && data.bars[row.getAttribute("data-rubylode-bar")];
    if (!bar) { return; }
    setUpHost(row, row.querySelector("a.rubylode-projects-bar-name"), "rubylode-overview-tracker-popover", "tooltip", fillBar(bar));
  });

  // ---- The sparklines in the list's Trend column

  var VIEW_BOX_WIDTH = 96;

  // The links of a week: the project's issue list, the week's query (the same for every project) and, for a project with
  // subprojects, the filter that includes or leaves out their issues, as the numbers were counted.
  function sparkUrl(project, sparks, week, kind) {
    var base = project.base;
    if (typeof base !== "string" || base.charAt(0) !== "/" || base.charAt(1) === "/") { return null; }
    return base + week[kind + "Query"] + (sparks.subprojectFilter[project.subprojects] || "");
  }

  function setUpSpark(spark, sparks) {
    var project = sparks.projects[spark.getAttribute("data-rubylode-spark")];
    var host = spark.parentNode;
    var polyline = spark.querySelector("polyline");
    if (!project || !polyline) { return; }
    var points = polyline.getAttribute("points").split(" ").map(function (pair) {
      var coordinates = pair.split(",");
      return { x: Number(coordinates[0]), y: Number(coordinates[1]) };
    });
    var graphic = spark.querySelector("svg");
    var svgNamespace = "http://www.w3.org/2000/svg";
    var marker = document.createElementNS(svgNamespace, "line");
    var dot = document.createElementNS(svgNamespace, "circle");
    marker.setAttribute("class", "rubylode-spark-marker");
    dot.setAttribute("class", "rubylode-spark-dot");
    dot.setAttribute("r", "2.6");
    marker.setAttribute("y1", "0");
    marker.setAttribute("y2", graphic.viewBox.baseVal.height);
    marker.style.display = "none";
    dot.style.display = "none";
    graphic.appendChild(marker);
    graphic.appendChild(dot);

    var popover = new Popover(host, "rubylode-spark-popover", "tooltip");
    var activeIndex = null;
    var shownAt = null;
    host.appendChild(popover.node);
    popover.returnFocusTo = function () { return spark; };
    popover.keepOpenWhile = function () { return host.contains(document.activeElement); };
    popover.onClose = function () {
      activeIndex = null;
      marker.style.display = "none";
      dot.style.display = "none";
      spark.removeAttribute("aria-describedby");
    };

    function fillWeek(index) {
      return function (node) {
        var week = sparks.weeks[index];
        node.appendChild(element("div", "rubylode-overview-tooltip-title", project.name));
        node.appendChild(element("div", "rubylode-overview-tooltip-heading", week.label));
        var figures = element("dl", "rubylode-overview-tooltip-figures");
        figures.appendChild(figureRow(strings.opened, project.opened[index]));
        figures.appendChild(figureRow(strings.closed, project.closed[index]));
        node.appendChild(figures);
        var links = element("div", "rubylode-overview-tooltip-links");
        links.appendChild(pathLink(null, strings.openedLink, sparkUrl(project, sparks, week, "opened")));
        links.appendChild(pathLink(null, strings.closedLink, sparkUrl(project, sparks, week, "closed")));
        node.appendChild(links);
      };
    }

    // Below the line, or above it when the window ends first. The card is fixed to the window, so the list's scroll box
    // cannot cut it off; scrolling closes it.
    function place(node) {
      var rect = spark.getBoundingClientRect();
      shownAt = { left: rect.left, top: rect.top };
      var left = rect.left;
      if (left + node.offsetWidth > document.documentElement.clientWidth - 8) { left = document.documentElement.clientWidth - node.offsetWidth - 8; }
      var top = rect.bottom + 6;
      if (top + node.offsetHeight > window.innerHeight - 8) { top = Math.max(8, rect.top - node.offsetHeight - 6); }
      node.style.left = Math.max(8, left) + "px";
      node.style.top = top + "px";
    }

    function showWeek(index) {
      if (index < 0 || index >= points.length) { return; }
      var point = points[index];
      activeIndex = index;
      marker.setAttribute("x1", point.x);
      marker.setAttribute("x2", point.x);
      dot.setAttribute("cx", point.x);
      dot.setAttribute("cy", point.y);
      marker.style.display = "";
      dot.style.display = "";
      popover.node.id = "rubylode-spark-tooltip-" + spark.getAttribute("data-rubylode-spark");
      spark.setAttribute("aria-describedby", popover.node.id);
      popover.show(fillWeek(index), place);
    }

    function indexAt(clientX) {
      var rect = graphic.getBoundingClientRect();
      var x = ((clientX - rect.left) / Math.max(rect.width, 1)) * VIEW_BOX_WIDTH;
      var nearest = 0;
      points.forEach(function (point, index) {
        if (Math.abs(point.x - x) < Math.abs(points[nearest].x - x)) { nearest = index; }
      });
      return nearest;
    }

    spark.addEventListener("mousemove", function (event) {
      var index = indexAt(event.clientX);
      if (index !== activeIndex) { showWeek(index); }
    });
    spark.addEventListener("mouseenter", function (event) { showWeek(indexAt(event.clientX)); });
    host.addEventListener("mouseleave", popover.hideSoon);
    spark.addEventListener("focus", function () { if (activeIndex === null) { showWeek(points.length - 1); } });
    host.addEventListener("focusout", function (event) {
      if (!host.contains(event.relatedTarget)) { popover.hideSoon(); }
    });
    spark.addEventListener("click", function (event) { showWeek(indexAt(event.clientX)); });
    spark.addEventListener("keydown", function (event) {
      if (event.altKey || event.ctrlKey || event.metaKey) { return; }
      var current = activeIndex === null ? points.length - 1 : activeIndex;
      var target = { ArrowRight: current + 1, ArrowLeft: current - 1, Home: 0, End: points.length - 1 }[event.key];
      if (target === undefined) { return; }
      event.preventDefault();
      showWeek(Math.min(Math.max(target, 0), points.length - 1));
    });
    // The card is fixed to the window, so it closes when scrolling moves the line away from it, and only then.
    window.addEventListener("scroll", function () {
      if (!popover.isOpen() || !shownAt) { return; }
      var rect = spark.getBoundingClientRect();
      if (Math.abs(rect.left - shownAt.left) > 1 || Math.abs(rect.top - shownAt.top) > 1) { popover.close(); }
    }, true);
  }

  if (data.sparks) {
    Array.prototype.forEach.call(document.querySelectorAll("[data-rubylode-spark]"), function (spark) { setUpSpark(spark, data.sparks); });
  }
})();
