/*
    Copyright (C) 2012 Johan Mattsson

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using Cairo;

namespace Supplement {

class Svg {

	/** Export to svg glyph data. */
	public static string to_svg_glyph (Glyph g) {	
		StringBuilder svg = new StringBuilder ();

		foreach (Path pl in g.path_list) {
			write_path_as_glyph (pl, svg, g);
		}
		
		return svg.str;
	}

	/** Export to svg-font data. */
	public static string to_svg_path (Path pl, Glyph g) {	
		StringBuilder svg = new StringBuilder ();
		pl.create_list ();
		write_path (pl, svg, g, false);
		return svg.str;
	}

	private static void write_path_as_glyph (Path pl, StringBuilder svg, Glyph g) {
		write_path (pl, svg, g, true);
	}

	private static void write_path (Path pl, StringBuilder svg, Glyph g, bool do_glyph) {
		int i = 0;
		EditPoint? n = null;
		EditPoint m;
		
		if (pl.points.length () <= 2) {
			return;
		}
		
		pl.create_list ();
			
		foreach (var e in pl.points) {
			if (i == 0) {
				add_abs_start (e, svg, g, do_glyph);
				i++;
				n = e;
				continue;
			}
			
			m = (!) n;

			add_abs_next (m, e, svg, g, do_glyph);
			
			n = e;
			i++;
		}

		m = pl.points.first ().data;	
		add_abs_next ((!) n, m, svg, g, do_glyph);
		
		close_path (svg);
	}

	private static void add_abs_next (EditPoint start, EditPoint end, StringBuilder svg, Glyph g, bool do_glyph) {
		if (end.get_left_handle ().type == PointType.QUADRATIC) {
			add_quadratic_abs_path (end, start, svg, g, do_glyph);
		} else if (start.right_handle.type == PointType.LINE && end.left_handle.type == PointType.LINE) {
			add_abs_line_to (end, start, svg, g, do_glyph);
		} else {
			add_cubic_abs_path (end, start, svg, g, do_glyph);
		}
	}

	private static void add_abs_start (EditPoint ep, StringBuilder svg, Glyph g, bool to_glyph) {		
		double left = g.left_limit;
		double baseline = Supplement.get_current_font ().base_line;
		double height = Supplement.get_current_font ().get_height ();
		
		svg.append_printf ("M");

		if (!to_glyph) {
			svg.append_printf ("%s ",  round (ep.x - left));
			svg.append_printf ("%s ",  round (-ep.y - baseline + height));
		} else {
			svg.append_printf ("%s ",  round (ep.x - left));
			svg.append_printf ("%s ",  round (ep.y + baseline));
		}
	}
		
	private static void close_path (StringBuilder svg) {
		svg.append ("z");
	}	
	
	private static void add_abs_line_to (EditPoint start, EditPoint stop, StringBuilder svg, Glyph g, bool to_glyph) {
		double baseline = Supplement.get_current_font ().base_line;
		double left = g.left_limit;
		
		double xa, ya, xb, yb;
		
		Path.get_line_points (start, stop, out xa, out ya, out xb, out yb);

		double height = Supplement.get_current_font ().get_height (); // no probably not

		double center_x = Glyph.xc ();
		double center_y = Glyph.yc ();
		
		svg.append ("L");
	
		if (!to_glyph) {
			svg.append_printf ("%s ", round (xb - center_x - left));
			svg.append_printf ("%s ", round (yb - center_y - baseline + height));	
		} else {
			svg.append_printf ("%s ", round (xb - center_x - left));
			svg.append_printf ("%s ", round (-yb + center_y + baseline));
		}
	}
	
	private static void add_quadratic_abs_path (EditPoint start, EditPoint end, StringBuilder svg, Glyph g,  bool to_glyph) {
		double left = g.left_limit;
		double baseline = Supplement.get_current_font ().base_line;
		double height = Supplement.get_current_font ().get_height (); // no probably not
		
		double xa, ya, xb, yb, xc, yc, xd, yd;
		
		Path.get_bezier_points (start, end, out xa, out ya, out xb, out yb, out xc, out yc, out xd, out yd);

		double center_x = Glyph.xc ();
		double center_y = Glyph.yc ();

		// FIXME xc or xd, right or left handle?:
		
		// cubic path
		if (!to_glyph) {
			svg.append_printf ("Q");

			svg.append_printf ("%s ", round (xb - center_x - left));
			svg.append_printf ("%s ", round (yb - center_y - baseline + height));
			
			svg.append_printf ("%s ", round (xd - center_x - left));
			svg.append_printf ("%s ", round (yd - center_y - baseline + height));

		} else {		
			svg.append_printf ("Q");

			svg.append_printf ("%s ", round (xb - center_x - left));
			svg.append_printf ("%s ", round (-yb + center_y + baseline));
			
			svg.append_printf ("%s ", round (xd - center_x - left));
			svg.append_printf ("%s ", round (-yd + center_y + baseline));	
		}
	}
			
	private static void add_cubic_abs_path (EditPoint start, EditPoint end, StringBuilder svg, Glyph g,  bool to_glyph) {
		double left = g.left_limit;
		double baseline = Supplement.get_current_font ().base_line;
		double height = Supplement.get_current_font ().get_height (); // no probably not
		
		double xa, ya, xb, yb, xc, yc, xd, yd;
		
		Path.get_bezier_points (start, end, out xa, out ya, out xb, out yb, out xc, out yc, out xd, out yd);

		double center_x = Glyph.xc ();
		double center_y = Glyph.yc ();
		
		// cubic path
		if (!to_glyph) {
			svg.append_printf ("C");

			svg.append_printf ("%s ", round (xb - center_x - left));
			svg.append_printf ("%s ", round (yb - center_y - baseline + height));
			
			svg.append_printf ("%s ", round (xc - center_x - left));
			svg.append_printf ("%s ", round (yc - center_y - baseline + height));
			
			svg.append_printf ("%s ", round (xd - center_x - left));
			svg.append_printf ("%s ", round (yd - center_y - baseline + height));	

		} else {		
			svg.append_printf ("C");

			svg.append_printf ("%s ", round (xb - center_x - left));
			svg.append_printf ("%s ", round (-yb + center_y + baseline));
			
			svg.append_printf ("%s ", round (xc - center_x - left));
			svg.append_printf ("%s ", round (-yc + center_y + baseline));	
			
			svg.append_printf ("%s ", round (xd - center_x - left));
			svg.append_printf ("%s ", round (-yd + center_y + baseline));	
		}
	}
	
	/** Draw path from svg font data. */
	public static void draw_svg_path (Context cr, string svg, double x, double y) {
		double x1, x2, x3;
		double y1, y2, y3;
		double px, py;
		string[] d = svg.split (" ");

		if (d.length == 0) {
			return;
		}
		
		px = 0;
		py = 0;
		
		cr.save ();

		cr.set_line_width (1);
		cr.set_source_rgba (0, 0, 0, 1);
		
		if (svg == "") {
			return;
		}
		
		for (int i = 0; i < d.length; i++) {
			
			// trim off leading white space	
			while (d[i].index_of (" ") == 0) { 
				d[i] = d[i].substring (1); // FIXME: maybe no ascii
			}
			
			if (d[i].index_of ("L") == 0) {
				x1 = double.parse (d[i].substring (1)) + x;
				y1 = -double.parse (d[i+1]) + y;
				cr.line_to (x1, y1);
				
				px = x1;
				py = y1;			
				continue;
			}

			if (d[i].index_of ("Q") == 0) {
				x1 = double.parse (d[i].substring (1)) + x;
				y1 = -double.parse (d[i+1]) + y;

				x2 = double.parse (d[i+2]) + x;
				y2 = -double.parse (d[i+3]) + y;
											
				cr.curve_to ((px + 2 * x1) / 3, (py + 2 * y1) / 3, (x2 + 2 * x1) / 3, (y2 + 2 * y1) / 3, x2, y2);
				
				px = x2;
				py = y2;
				continue;
			}
			
			if (d[i].index_of ("C") == 0) {
				x1 = double.parse (d[i].substring (1)) + x;
				y1 = -double.parse (d[i+1]) + y;

				x2 = double.parse (d[i+2]) + x;
				y2 = -double.parse (d[i+3]) + y;

				x3 = double.parse (d[i+4]) + x;
				y3 = -double.parse (d[i+5]) + y;
																
				cr.curve_to (x1, y1, x2, y2, x3, y3);
				
				px = x3;
				py = y3;
				continue;
			}

			if (d[i].index_of ("M") == 0) {
				x1 = double.parse (d[i].substring (1)) + x;
				y1 = -double.parse (d[i+1]) + y;
				
				cr.move_to (x1, y1);

				px = x1;
				py = y1;
				continue;
			}
								
			if (d[i].index_of ("zM") == 0) {
				cr.close_path ();
				
				x1 = double.parse (d[i].substring (2)) + x;
				y1 = -double.parse (d[i+1]) + y;
				
				cr.move_to (x1, y1);

				px = x1;
				py = y1;
				continue;
			}

			if (d[i].index_of ("z") == 0) {
				cr.close_path ();
				continue;
			}
		
		}
		
		cr.fill ();
		cr.restore ();
	}

}

internal static string round (double p) {
	string v = p.to_string ();
	char[] c = new char [501];
	
	v = p.format (c, "%3.15f");
	
	if (v.index_of ("e") != -1) {	
		return "0.0";
	}
	
	return v;
}
	
}
