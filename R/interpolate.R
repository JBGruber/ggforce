#' @rdname ggforce-extensions
#' @format NULL
#' @usage NULL
#' @importFrom grid segmentsGrob polylineGrob gpar
GeomPathInterpolate <- ggproto('GeomPathInterpolate', GeomPath,
  draw_panel = function(data, panel_scales, coord, arrow = NULL,
                          lineend = 'butt', linejoin = 'round', linemitre = 1,
                          na.rm = FALSE) {
    if (!anyDuplicated(data$group)) {
      message(
        'geom_path_interpolate: Each group consists of only one observation. ',
        'Do you need to adjust the group aesthetic?'
      )
    }
    data <- data[order(data$group), , drop = FALSE]
    data <- interpolateDataFrame(data)
    munched <- coord_munch(coord, data, panel_scales)
    rows <- stats::ave(seq_len(nrow(munched)), munched$group,
      FUN = length
    )
    munched <- munched[rows >= 2, ]
    if (nrow(munched) < 2) {
      return(zeroGrob())
    }
    attr <- dapply(data, 'group', function(df) {
      new_data_frame(list(
        solid = identical(unique(df$linetype), 1),
        constant = nrow(unique(df[, c(
          'alpha', 'colour',
          'size', 'linetype'
        )])) == 1
      ))
    })

    solid_lines <- all(attr$solid)
    constant <- all(attr$constant)
    if (!solid_lines && !constant) {
      stop('geom_path_interpolate: If you are using dotted or dashed lines',
        ', colour, size and linetype must be constant over the line',
        call. = FALSE
      )
    }
    n <- nrow(munched)
    group_diff <- munched$group[-1] != munched$group[-n]
    start <- c(TRUE, group_diff)
    end <- c(group_diff, TRUE)
    if (!constant) {
      segmentsGrob(munched$x[!end], munched$y[!end], munched$x[!start],
        munched$y[!start],
        default.units = 'native', arrow = arrow,
        gp = gpar(
          col = alpha(munched$colour, munched$alpha)[!end],
          fill = alpha(munched$colour, munched$alpha)[!end],
          lwd = munched$size[!end] * .pt, lty = munched$linetype[!end],
          lineend = lineend, linejoin = linejoin, linemitre = linemitre
        )
      )
    }
    else {
      id <- match(munched$group, unique(munched$group))
      polylineGrob(munched$x, munched$y,
        id = id, default.units = 'native',
        arrow = arrow, gp = gpar(
          col = alpha(
            munched$colour,
            munched$alpha
          )[start], fill = alpha(
            munched$colour,
            munched$alpha
          )[start], lwd = munched$size[start] *
            .pt, lty = munched$linetype[start], lineend = lineend,
          linejoin = linejoin, linemitre = linemitre
        )
      )
    }
  },
  handle_na = function(data, params) {
    data
  }
)
#' Interpolate layer data
#'
#' @param A data.frame with data for a layer
#'
#' @return A similar data.frame with NA values interpolated
#'
#' @importFrom tweenr tween_t
#' @keywords internal
#' @export
interpolateDataFrame <- function(data) {
  if (is.null(data$group)) {
    stop('data must have a group column')
  }
  interpLengths <- lengths(split(data$group, data$group))
  for (i in seq_len(ncol(data))) {
    if (names(data)[i] %in% c('x', 'y', 'index', 'group', '.interp') ||
        all(is.na(data[[i]]))) {
      next
    }
    if (any(!is.na(data[[i]][data$.interp])) &&
        length(unique(data[[i]][data$.interp])) > 1) {
      next
    }
    interpValues <- split(data[[i]][!data$.interp], data$group[!data$.interp])
    data[[i]] <- unlist(tween_t(interpValues, interpLengths))
  }
  data[, names(data) != '.interp']
}
