/*
	Copyright (C) 2012 2013 2015 Johan Mattsson

	This library is free software; you can redistribute it and/or modify 
	it under the terms of the GNU Lesser General Public License as 
	published by the Free Software Foundation; either version 3 of the 
	License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful, but 
	WITHOUT ANY WARRANTY; without even the implied warranty of 
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
	Lesser General Public License for more details.
*/

using Math;
using Cairo;

namespace BirdFont {

public class MoveTool : Tool {

	static bool move_path = false;
	static bool moved = false;
	static double last_x = 0;
	static double last_y = 0;
	
	static double selection_x = 0;
	static double selection_y = 0;	
	static bool group_selection= false;
	
	public static static double selection_box_width = 0;
	public static static double selection_box_height = 0;
	public static static double selection_box_center_x = 0;
	public static static double selection_box_center_y = 0;
	
	public signal void selection_changed ();
	public signal void objects_moved ();
	public signal void objects_deselected ();
	
	public MoveTool (string n) {
		base (n, t_("Move paths"));

		selection_changed.connect (() => {
			update_selection_boundaries ();
			redraw();
		});
		
		objects_deselected.connect (() => {
			update_selection_boundaries ();
			redraw();
		});
		
		select_action.connect((self) => {
			MainWindow.get_current_glyph ().close_path ();
		});

		deselect_action.connect((self) => {
		});
				
		press_action.connect((self, b, x, y) => {
			press (b, x, y);
		});

		release_action.connect((self, b, x, y) => {
			release (b, x, y);
		});
		
		move_action.connect ((self, x, y)	 => {
			move (x, y);
		});
		
		key_press_action.connect ((self, keyval) => {
			key_down (keyval);
		});
		
		draw_action.connect ((self, cr, glyph) => {
			draw_actions (cr);
		});
	}
	
	public static void draw_actions (Context cr) {
		if (group_selection) {
			draw_selection_box (cr);
		}
	}
	
	public void key_down (uint32 keyval) {
		Glyph g = MainWindow.get_current_glyph ();
		
		// delete selected paths
		if (keyval == Key.DEL || keyval == Key.BACK_SPACE) {
			
			if (g.active_paths.size > 0) {
				g.store_undo_state ();
			}
			
			foreach (Object p in g.active_paths) {
				if (p is FastPath) {
					g.layers.remove_path (((FastPath) p).get_path ());
				} else {
					g.layers.remove (p);
				}
				
				g.update_view ();
			}

			g.active_paths.clear ();
		}
		
		if (is_arrow_key (keyval)) {
			move_selected_paths (keyval);
		}
	}
	
	public void move (int x, int y) {
		Glyph glyph = MainWindow.get_current_glyph ();
		double dx = Glyph.path_coordinate_x (last_x) - Glyph.path_coordinate_x (x);
		double dy = Glyph.path_coordinate_y (last_y) - Glyph.path_coordinate_y (y); 
		double delta_x, delta_y;
		
		if (!move_path) {
			return;
		}
		
		if (move_path && (fabs(dx) > 0 || fabs (dy) > 0)) {
			moved = true;

			delta_x = -dx;
			delta_y = -dy;
			
			if (glyph.color_svg_data != null) {
				glyph.svg_x += delta_x;
				glyph.svg_y += delta_y;
			} else {		
				foreach (Layer group in glyph.selected_groups) {
					if (group.gradient != null) {
						Gradient g = (!) group.gradient;
						g.x1 += delta_x;
						g.x2 += delta_x;
						g.y1 += delta_y;
						g.y2 += delta_y;
					}
				}
				
				foreach (Object object in glyph.active_paths) {
					object.move (delta_x, delta_y);
				}
			}
		}

		last_x = x;
		last_y = y;

		update_selection_boundaries ();
		
		if (glyph.active_paths.size > 0) {
			objects_moved ();
		}
		
		BirdFont.get_current_font ().touch ();

		GlyphCanvas.redraw ();
		PenTool.reset_stroke ();
	}
	
	public void release (int b, int x, int y) {
		Glyph glyph = MainWindow.get_current_glyph ();
		
		move_path = false;
		
		if (GridTool.is_visible () && moved) {
			tie_paths_to_grid (glyph);
		} else if (GridTool.has_ttf_grid ()) {
			foreach (Object p in glyph.active_paths) {
				tie_path_to_ttf_grid (p);
			}
		} 
		
		if (group_selection) {
			select_group ();
		}
		
		group_selection = false;
		moved = false;
		
		if (glyph.active_paths.size > 0) {
			selection_changed ();
			objects_moved ();
			DrawingTools.resize_tool.signal_objects_rotated ();
			
			foreach (Object o in glyph.active_paths) {
				if (o is FastPath) {
					FastPath path = (FastPath) o;
					path.get_path ().create_full_stroke ();
				}
			}
		} else {
			objects_deselected ();
		}
	}
		
	public void press (int b, int x, int y) {
		Glyph glyph = MainWindow.get_current_glyph ();
		Object object;
		bool selected = false;
		Layer? group;
		Layer g;
		
		glyph.store_undo_state ();
		group_selection = false;
		
		if (glyph.color_svg_data == null) {
			group = glyph.get_path_at (x, y);
			
			if (group != null) {
				g = (!) group;
				return_if_fail (g.objects.objects.size > 0);
				object = g.objects.objects.get (0);
				selected = glyph.active_paths_contains (object);
				
				if (!selected && !KeyBindings.has_shift ()) {
					glyph.clear_active_paths ();
				} 
				
				foreach (Object lp in g.objects) {
					if (selected && KeyBindings.has_shift ()) {
						glyph.selected_groups.remove ((!) group);
						glyph.active_paths.remove (lp);
					} else {
						glyph.add_active_object ((!) group, lp);
					}
				}
			} else if (!KeyBindings.has_shift ()) {
				glyph.clear_active_paths ();
			}
			
			update_selection_boundaries ();
		}
		
		move_path = true;
		
		last_x = x;
		last_y = y;
		
		if (glyph.active_paths.size == 0) {
			group_selection = true;
			selection_x = x;
			selection_y = y;	
		}
		
		update_boundaries_for_selection ();
		selection_changed ();
		GlyphCanvas.redraw ();
	}
		
	void select_group () {
		double x1 = Glyph.path_coordinate_x (Math.fmin (selection_x, last_x));
		double y1 = Glyph.path_coordinate_y (Math.fmin (selection_y, last_y));
		double x2 = Glyph.path_coordinate_x (Math.fmax (selection_x, last_x));
		double y2 = Glyph.path_coordinate_y (Math.fmax (selection_y, last_y));
		Glyph glyph = MainWindow.get_current_glyph ();
		
		glyph.clear_active_paths ();
		
		foreach (Object p in glyph.get_objects_in_current_layer ()) {
			if (p.xmin > x1 && p.xmax < x2 && p.ymin < y1 && p.ymax > y2) {
				if (!p.is_empty ()) {
					glyph.add_active_object (null, p);
				}
			}
		}
		
		selection_changed ();
	}
	
	public static void update_selection_boundaries () {
		get_selection_box_boundaries (out selection_box_center_x,
			out selection_box_center_y, out selection_box_width,
			out selection_box_height);	
	}

	public void move_to_baseline () {
		Glyph glyph = MainWindow.get_current_glyph ();
		Font font = BirdFont.get_current_font ();
		double x, y, w, h;
		
		get_selection_box_boundaries (out x, out y, out w, out h);
		
		foreach (Object path in glyph.active_paths) {
			path.move (glyph.left_limit - x + w / 2, font.base_line - y + h / 2);
		}
		
		update_selection_boundaries ();
		objects_moved ();
		GlyphCanvas.redraw ();
	}

	static void draw_selection_box (Context cr) {
		double x = Math.fmin (selection_x, last_x);
		double y = Math.fmin (selection_y, last_y);

		double w = Math.fabs (selection_x - last_x);
		double h = Math.fabs (selection_y - last_y);
		
		Glyph glyph = MainWindow.get_current_glyph ();
		
		if (glyph.color_svg_data == null) {
			cr.save ();			
			Theme.color (cr, "Foreground 1");
			cr.set_line_width (2);
			cr.rectangle (x, y, w, h);
			cr.stroke ();
			cr.restore ();
		}
	}
	
	public static void get_selection_box_boundaries (out double x, out double y, out double w, out double h) {
		double px, py, px2, py2;
		Glyph glyph = MainWindow.get_current_glyph ();
		
		px = 10000;
		py = 10000;
		px2 = -10000;
		py2 = -10000;
		
		foreach (Object o in glyph.active_paths) {
			if (o is FastPath) {
				Path p = ((FastPath) o).get_path ();
				p.update_region_boundaries ();
				
				if (px > p.xmin) {
					px = p.xmin;
				} 

				if (py > p.ymin) {
					py = p.ymin;
				}

				if (px2 < p.xmax) {
					px2 = p.xmax;
				}
				
				if (py2 < p.ymax) {
					py2 = p.ymax;
				}
			}
		}
		
		w = px2 - px;
		h = py2 - py;
		x = px + (w / 2);
		y = py + (h / 2);
	}
	
	void move_selected_paths (uint key) {
		Glyph glyph = MainWindow.get_current_glyph ();
		double x, y;
		
		x = 0;
		y = 0;
		
		switch (key) {
			case Key.UP:
				y = 1;
				break;
			case Key.DOWN:
				y = -1;
				break;
			case Key.LEFT:
				x = -1;
				break;
			case Key.RIGHT:
				x = 1;
				break;
			default:
				break;
		}
		
		foreach (Object path in glyph.active_paths) {
			path.move (x * Glyph.ivz (), y * Glyph.ivz ());
		}
		
		BirdFont.get_current_font ().touch ();
		PenTool.reset_stroke ();
		update_selection_boundaries ();
		objects_moved ();
		glyph.redraw_area (0, 0, glyph.allocation.width, glyph.allocation.height);
	}

	static void tie_path_to_ttf_grid (Object p) {
		double sx, sy, qx, qy;	

		sx = p.xmax;
		sy = p.ymax;
		qx = p.xmin;
		qy = p.ymin;
		
		GridTool.ttf_grid_coordinate (ref sx, ref sy);
		GridTool.ttf_grid_coordinate (ref qx, ref qy);
	
		if (Math.fabs (qy - p.ymin) < Math.fabs (sy - p.ymax)) {
			p.move (0, qy - p.ymin);
		} else {
			p.move (0, sy - p.ymax);
		}

		if (Math.fabs (qx - p.xmin) < Math.fabs (sx - p.xmax)) {
			p.move (qx - p.xmin, 0);
		} else {
			p.move (sx - p.xmax, 0);
		}		
	} 

	static void tie_paths_to_grid (Glyph g) {
		double sx, sy, qx, qy;	
		double dx_min, dx_max, dy_min, dy_max;;
		double maxx, maxy, minx, miny;
		
		update_selection_boundaries ();	
		
		// tie to grid
		maxx = selection_box_center_x + selection_box_width / 2;
		maxy = selection_box_center_y + selection_box_height / 2;
		minx = selection_box_center_x - selection_box_width / 2;
		miny = selection_box_center_y - selection_box_height / 2;
		
		sx = maxx;
		sy = maxy;
		qx = minx;
		qy = miny;
		
		GridTool.tie_coordinate (ref sx, ref sy);
		GridTool.tie_coordinate (ref qx, ref qy);
		
		dy_min = Math.fabs (qy - miny);
		dy_max = Math.fabs (sy - maxy);
		dx_min = Math.fabs (qx - minx);
		dx_max = Math.fabs (sx - maxx);
		
		foreach (Object p in g.active_paths) {
			if (dy_min < dy_max) {
				p.move (0, qy - miny);
			} else {
				p.move (0, sy - maxy);
			}

			if (dx_min < dx_max) {
				p.move (qx - minx, 0);
			} else {
				p.move (sx - maxx, 0);
			}
		}
		
		update_selection_boundaries ();		
	}
	
	public static void update_boundaries_for_selection () {
		Glyph glyph = MainWindow.get_current_glyph ();
		foreach (Object o in glyph.active_paths) {
			if (o is FastPath) {
				((FastPath)o).get_path ().update_region_boundaries ();
			}
		}
	}
	
	public static void flip_vertical () {
		flip (true);
	}
	
	public static void flip_horizontal () {
		flip (false);
	}

	public static void flip (bool vertical) {
		double xc, yc, xc2, yc2, w, h;		
		double dx, dy;
		Glyph glyph = MainWindow.get_current_glyph ();  
		
		update_selection_boundaries ();
		
		xc = selection_box_center_x;
		yc = selection_box_center_y;

		foreach (Object p in glyph.active_paths) {
			if (p is FastPath) {
				Path path = ((FastPath) p).get_path ();
				
				// FIXME: move to object
				if (vertical) {
					path.flip_vertical ();
				} else {
					path.flip_horizontal ();
				}
				
				path.reverse ();
			}
		}

		get_selection_box_boundaries (out xc2, out yc2, out w, out h); 

		dx = -(xc2 - xc);
		dy = -(yc2 - yc);
		
		foreach (Object p in glyph.active_paths) {
			p.move (dx, dy);
		}
		
		update_selection_boundaries ();
		PenTool.reset_stroke ();
		
		BirdFont.get_current_font ().touch ();
	}
	
	public void select_all_paths () {
		Glyph g = MainWindow.get_current_glyph ();
		
		g.clear_active_paths ();
		foreach (Object p in g.get_objects_in_current_layer ()) {
			if (!p.is_empty ()) {
				g.add_active_object (null, p);
			}
		}
		
		g.update_view ();
		
		update_selection_boundaries ();
		objects_moved ();
	}
}

}
