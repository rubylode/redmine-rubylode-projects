# Theming

The cards use plain CSS (`assets/stylesheets/projects.css`), and every color and size in it is a `--rubylode-projects-*`
custom property. The plugin sets its defaults in `:where(:root)`, which has no specificity, so a theme wins whenever it
sets a property, on `:root` or on any element, whatever order the stylesheets load in.

Colors:

| Property | Default | Used for |
|---|---|---|
| `--rubylode-projects-page-background` | `#f2f4f7` | the area behind the cards |
| `--rubylode-projects-card-background` | `#ffffff` | the cards |
| `--rubylode-projects-card-border-color` | `#e1e5eb` | card borders and row dividers |
| `--rubylode-projects-card-shadow` | a faint shadow | card shadow (a `box-shadow` value) |
| `--rubylode-projects-text-color` | `inherit` | card text |
| `--rubylode-projects-muted-text-color` | `#5d6672` | notes, issue numbers, axis labels, the subtitle |
| `--rubylode-projects-label-text-color` | `#4a5360` | upper-case labels (tiles, roles, time) |
| `--rubylode-projects-accent-color` | `#1f5f8b` | tracker bars |
| `--rubylode-projects-opened-color` | `#9cc3e0` | "opened" bars and swatch |
| `--rubylode-projects-closed-color` | `#1f5f8b` | "closed" bars and swatch |
| `--rubylode-projects-done-color` | `#4caf50` | the done bar |
| `--rubylode-projects-meter-track-color` | `#e3e8ee` | the empty part of a bar |
| `--rubylode-projects-grid-line-color` | `#e7eaef` | chart grid lines |
| `--rubylode-projects-chip-background` | `#eaf2f9` | subproject chips, "in progress" status chips |
| `--rubylode-projects-chip-border-color` | `#cfe0ee` | subproject chip borders |
| `--rubylode-projects-chip-text-color` | `#1f5f8b` | chip text |
| `--rubylode-projects-waiting-background` | `#f1f3f6` | status chips of issues not started |
| `--rubylode-projects-waiting-text-color` | `#4a5360` | their text |
| `--rubylode-projects-priority-background` | `#fdecea` | priority chips |
| `--rubylode-projects-priority-text-color` | `#a1281c` | their text |

Sizes:

| Property | Default | Used for |
|---|---|---|
| `--rubylode-projects-gap` | `14px` | space between and around cards |
| `--rubylode-projects-card-padding` | `14px 16px` | inside a card |
| `--rubylode-projects-card-radius` | `10px` | card and card-area corners |
| `--rubylode-projects-chip-radius` | `8px` | subproject chip corners |
| `--rubylode-projects-tile-minimum-width` | `170px` | narrowest tile before the tiles wrap |
| `--rubylode-projects-meter-height` | `8px` | thickness of the bars |
| `--rubylode-projects-swatch-size` | `10px` | legend swatches |
| `--rubylode-projects-member-label-width` | `8em` | the role column |
| `--rubylode-projects-time-label-width` | `12em` | the label column of the time card |
| `--rubylode-projects-heading-size` | `1.05em` | card headings, tracker names |
| `--rubylode-projects-tile-value-size` | `2em` | the big numbers |
| `--rubylode-projects-label-size` | `0.8em` | upper-case labels |
| `--rubylode-projects-small-text-size` | `0.92em` | notes, chips, the classic-overview link |
| `--rubylode-projects-subtitle-size` | `1em` | the subtitle |
| `--rubylode-projects-axis-label-size` | `11px` | chart axis labels |
| `--rubylode-projects-space-small` | `0.35em` | small spacing |
| `--rubylode-projects-space-medium` | `0.6em` | medium spacing |
| `--rubylode-projects-space-large` | `1em` | large spacing |

Tooltips, popovers and the week highlight:

| Property | Default | Used for |
|---|---|---|
| `--rubylode-projects-tooltip-background` | the card background | the cards that appear on hover |
| `--rubylode-projects-tooltip-text-color` | the text color | their text |
| `--rubylode-projects-tooltip-border-color` | the card border color | their border and dividers |
| `--rubylode-projects-tooltip-shadow` | `0 8px 24px rgba(16, 24, 40, 0.22)` | their shadow |
| `--rubylode-projects-highlight-color` | 14% of the accent color | the column behind the week being looked at |
| `--rubylode-projects-dim-opacity` | `0.45` | the bars of the other weeks while one is looked at |
| `--rubylode-projects-tooltip-minimum-width` | `15em` | narrowest tooltip |
| `--rubylode-projects-tooltip-maximum-width` | `26em` | widest tooltip |

The projects list adds these (dark mode follows the theme: each one defaults to a property above, so a theme that restyles
the cards restyles these):

| Property | Default | Used for |
|---|---|---|
| `--rubylode-projects-summary-tile-minimum-width` | `130px` | narrowest summary tile |
| `--rubylode-projects-overdue-color` | `#c0392b` | a non-zero Overdue count |
| `--rubylode-projects-progress-width` | `6.5em` | the % done bar's length |
| `--rubylode-projects-progress-height` | `6px` | its thickness |
| `--rubylode-projects-progress-track-color` | the meter track color | the empty part of the % done bar |
| `--rubylode-projects-progress-fill-color` | the done color | its filled part |
| `--rubylode-projects-bar-fill-color` | the accent color | the bars of "Where the work is" |
| `--rubylode-projects-bar-track-color` | the meter track color | their empty part |
| `--rubylode-projects-bar-height` | `10px` | their thickness |
| `--rubylode-projects-bar-name-width` | `9em` | the project name column of the bars |
| `--rubylode-projects-sparkline-width` | `96px` | the Trend sparkline's width |
| `--rubylode-projects-sparkline-height` | `26px` | its height |
| `--rubylode-projects-sparkline-line-color` | the closed color | its line and dot |
| `--rubylode-projects-sparkline-area-color` | 16% of the closed color | the area under it |
| `--rubylode-projects-sparkline-marker-color` | the muted text color | the marker on the hovered week |

The tooltip colors default to the card colors and the highlight to a tint of the accent color, so a dark theme that
restyles the cards restyles the tooltips and the highlight with them.

The projects table adds these (each defaults to a property above, so a dark theme that restyles the cards restyles the table):

| Property | Default | Used for |
|---|---|---|
| `--rubylode-projects-table-border-color` | the card border color | row dividers |
| `--rubylode-projects-table-header-text-color` | the label text color | column headings |
| `--rubylode-projects-table-row-hover-background` | the highlight color | the row under the pointer |
| `--rubylode-projects-table-indent` | `1.25em` | indent per subproject level |
| `--rubylode-projects-table-description-width` | `24em` | widest the description column grows |
| `--rubylode-projects-table-bar-width` | `5em` | the done bar's length |
| `--rubylode-projects-table-bar-height` | `6px` | its thickness |
| `--rubylode-projects-table-bar-track-color` | the meter track color | its empty part |
| `--rubylode-projects-table-bar-fill-color` | the done color | its filled part |
| `--rubylode-projects-table-focus-color` | the accent color | the keyboard focus outline |

A block to paste into a theme and adjust (soft grey page, white cards, a blue ramp from light to dark):

    :root {
      --rubylode-projects-page-background: #f4f5f7;
      --rubylode-projects-card-background: #ffffff;
      --rubylode-projects-card-border-color: #e3e6ea;
      --rubylode-projects-muted-text-color: #5b6470;
      --rubylode-projects-opened-color: #a9c8ec;       /* blue 200 */
      --rubylode-projects-accent-color: #2f6fc0;       /* blue 600 */
      --rubylode-projects-closed-color: #1d4f91;       /* blue 800 */
      --rubylode-projects-chip-background: #e8f1fb;    /* blue 50 */
      --rubylode-projects-chip-border-color: #c9ddf4;  /* blue 100 */
      --rubylode-projects-chip-text-color: #1d4f91;    /* blue 800 */
      --rubylode-projects-card-radius: 12px;
    }
