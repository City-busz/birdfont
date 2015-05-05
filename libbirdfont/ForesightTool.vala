/*
    Copyright (C) 2014 2015 Johan Mattsson

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

/** Create Beziér curves and preview the path. */
public class ForesightTool : Tool {
	
	public const uint NONE = 0;
	public const uint MOVE_POINT = 1;
	public const uint MOVE_HANDLES = 2;
	public const uint MOVE_LAST_HANDLE = 3;
	public const uint MOVE_FIRST_HANDLE = 4;
	
	uint state = NONE;
	bool move_right_handle = true;
	int previous_point = 0;
	
	Path current_path = new Path ();

	int last_move_x = 0;
	int last_move_y = 0;

	public bool skip_deselect = false;

	static int press_counter = 0;
	double last_release_time = 0;
	
	public ForesightTool (string name) {
		base (name, t_ ("Create Beziér curves"));

		select_action.connect ((self) => {
			PenTool p = (PenTool) PointTool.pen ();
		
			if (state != NONE) {
				p.release_action (p, 1, last_move_x, last_move_y);
			}
			
			MainWindow.get_current_glyph ().clear_active_paths ();
			MainWindow.set_cursor (NativeWindow.VISIBLE);
			state = NONE;
		});

		deselect_action.connect ((self) => {
			PenTool p = (PenTool) PointTool.pen ();
			
			if (state != NONE) {
				p.release_action (p, 1, last_move_x, last_move_y);
			}
			
			MainWindow.set_cursor (NativeWindow.VISIBLE);
			state = NONE;
		});
		
		press_action.connect ((self, b, x, y) => {
			// ignore double clicks
			if ((GLib.get_real_time () - last_release_time) / 1000000.0 < 0.2) {
				print ("Double click.");
				last_release_time = GLib.get_real_time ();
				MainWindow.set_cursor (NativeWindow.VISIBLE);
				return;
			}
			last_release_time = GLib.get_real_time ();

			press (b, x, y);
		});

		double_click_action.connect ((self, b, x, y) => {
			EditPoint last;
			get_active_path ().delete_last_point ();
			
			last = get_active_path ().get_last_point ();
			
			PenTool.selected_points.clear ();
			PenTool.selected_points.add (new PointSelection (last, get_active_path ()));	
			PenTool.selected_point = last; 
			PenTool.active_edit_point = null;
		});

		release_action.connect ((self, b, x, y) => {
			PenTool p = (PenTool) PointTool.pen ();
			PointSelection last;
			
			last_move_x = x;
			last_move_y = y;
				
			if (b == 2) {
				return;
			}
			
			if (state == MOVE_HANDLES || state == MOVE_FIRST_HANDLE) {
				if (state != MOVE_FIRST_HANDLE) {
					last = add_new_point (x, y);	
				}
				
				state = MOVE_POINT;
				move_action (this, x, y);
			} else if (state == MOVE_LAST_HANDLE) {
				previous_point = 0;
				
				if (unlikely (PenTool.selected_points.size == 0)) {
					warning ("No point in move last handle.");
					return;
				}
				
				last = PenTool.selected_points.get (PenTool.selected_points.size - 1);
				
				p.release_action (p, 2, x, y);
				
				PenTool.selected_points.add (last);
				PenTool.active_path.highlight_last_segment = false;
				
				last.path.direction_is_set = false;
				PenTool.force_direction ();
				
				state = NONE;
				MainWindow.set_cursor (NativeWindow.VISIBLE);
			} else if (state == MOVE_POINT) {
			} else if (state == NONE) {
			} else {
				warning (@"Unknown state $state.");
			}
			
			current_path.hide_end_handle = true;
		});

		move_action.connect ((self, x, y) => {
			Tool p =  PointTool.pen ();
			PointSelection last;
			bool lh;
			EditPointHandle h;
			Path a;
			
			last_move_x = x;
			last_move_y = y;
			
			a = get_active_path ();
			if (a.is_open () && a.points.size > 1) {
				a.get_first_point ().set_reflective_handles (false);
				a.get_first_point ().set_tie_handle (false);
			}
							
			if (MainWindow.dialog.visible && state != NONE) {
				state = NONE;
				p.release_action (p, 1, last_move_x, last_move_y);
			}
			
			if (state == NONE) {
				MainWindow.set_cursor (NativeWindow.VISIBLE);
			}
			
			PenTool.active_path = current_path;
			PenTool.active_path.hide_end_handle = (state == MOVE_POINT);
			
			if (state == MOVE_HANDLES || state == MOVE_LAST_HANDLE) {			
				if (previous_point > 0) {
					return_if_fail (PenTool.active_path.points.size >= previous_point + 1);
					return_if_fail (PenTool.active_path.points.size > 0);
					last = new PointSelection (PenTool.active_path.points.get (PenTool.active_path.points.size - (previous_point + 1)), PenTool.active_path);				
				} else {
					if (unlikely (PenTool.selected_points.size == 0)) {
						warning ("No point to move in state %u", state);
						return;
					}
					last = PenTool.selected_points.get (PenTool.selected_points.size - 1);
					
					if (last.point.get_right_handle ().is_line () || last.point.get_left_handle ().is_line ()) {
						last.point.convert_to_curve ();
						last.point.get_right_handle ().length = 0.1;
						last.point.get_left_handle ().length = 0.1;
					}
				}
				
				PenTool.move_selected_handle = true;
				PenTool.move_selected = false;
				
				lh = (state == MOVE_LAST_HANDLE);
				
				if (!move_right_handle) {
					lh = !lh;
				}
				
				if (previous_point > 0) {
					lh = false;
				}
				
				h = (lh) ? last.point.get_left_handle () : last.point.get_right_handle ();
				PenTool.selected_handle = h;
				PenTool.active_handle = h;
				
				if (previous_point == 0 
					&& !last.point.reflective_point
					&& !last.point.tie_handles) {
					
					last.point.convert_to_curve ();
					last.point.set_reflective_handles (true);
					last.point.get_right_handle ().length = 0.1;
					last.point.get_left_handle ().length = 0.1;
				}
				
				if (previous_point == 0) {
					last.point.set_reflective_handles (true);
				}
				
				if (previous_point > 0) {
					PenTool.retain_angle = last.point.tie_handles;
				}
				
				if (h.is_line ()) {
					last.point.convert_to_curve ();
					last.point.get_right_handle ().length = 0.1;
					last.point.get_left_handle ().length = 0.1;
				}
				
				p.move_action (p, x, y);
				last.point.set_reflective_handles (false);
				
				PenTool.selected_handle = h;
				PenTool.active_handle = h;
				
				PenTool.move_selected_handle = false;
				last.path.highlight_last_segment = true;
				
				if (previous_point == 0) {
					last.point.set_tie_handle (true);
					p.move_action (p, x, y);
				}
				
				PenTool.retain_angle = false;
				
				MainWindow.set_cursor (NativeWindow.HIDDEN);
			} else {
				if (DrawingTools.get_selected_point_type () != PointType.QUADRATIC) {
					p.move_action (p, x, y);
				} else {
					PenTool.move_point_independent_of_handle = true;
					p.move_action (p, x, y);
					PenTool.move_point_independent_of_handle = false;
				}
			}
			
			if (PenTool.active_path.points.size < 3) {
				PenTool.active_edit_point = null;
			}
		});
		
		key_press_action.connect ((self, keyval) => {
			PenTool p = (PenTool) PointTool.pen ();
			p.key_press_action (p, keyval);
		});
		
		key_release_action.connect ((self, keyval) => {
			Tool p = PointTool.pen ();
			p.key_release_action (p, keyval);
			MainWindow.set_cursor (NativeWindow.VISIBLE);
		});
		
		draw_action.connect ((tool, cairo_context, glyph) => {
			Tool p = PointTool.pen ();
			p.draw_action (p, cairo_context, glyph);
		});
	}
	
	public void press (int b, int x, int y) {
		PenTool p = (PenTool) PointTool.pen ();
		PointSelection ps;
		EditPoint first_point;
		bool clockwise;
		Path? path = null;
		bool one_point = false;
		Glyph g;
		
		MainWindow.set_cursor (NativeWindow.HIDDEN);

		BirdFont.get_current_font ().touch ();
		g = MainWindow.get_current_glyph ();
		g.store_undo_state ();

		if (b == 2) {
			last_move_x = x;
			last_move_y = y;
			
			stop_drawing ();
			
			move_action (this, x, y);
			return;
		} 
		
		if (state == NONE) {
			state = MOVE_POINT;
			
			PenTool.active_path = get_active_path ();
			
			add_new_point (x, y);
			
			PenTool.last_point_x = Glyph.path_coordinate_x (x);
			PenTool.last_point_y = Glyph.path_coordinate_y (y);
			
			move_action (this, x, y);
			state = MOVE_FIRST_HANDLE;
			
			press_action(this, b, x, y);
			release_action(this, b, x, y);
		}
		
		if (previous_point > 0) {
			previous_point = 0;
			state = MOVE_POINT;
		}
		
		if (previous_point == 0) {
			if (state == MOVE_POINT) {			
				state = MOVE_HANDLES;
				
				path = PenTool.find_path_to_join ();
				
				if (path != null) {
					one_point = (((!) path).points.size == 1);
				}
				
				if (p.has_join_icon ()) {
					// FIXME: last activa path in list
					ps = new PointSelection (PenTool.active_path.points.get (PenTool.active_path.points.size - 1), PenTool.active_path);
					ps.point.set_tie_handle (false);
					
					ps = new PointSelection (PenTool.active_path.points.get (0), PenTool.active_path);
					ps.point.set_tie_handle (false);
					
					first_point = PenTool.active_path.points.get (0);
					clockwise = PenTool.active_path.is_clockwise ();

					PenTool.move_selected = false;
					p.release_action (p, 2, x, y);
					
					PenTool.move_selected = false;
					p.press_action (p, 2, x, y);
					
					if (ps.path.has_point (first_point)) {
						ps.path.reverse ();
					}
					
					if (clockwise && PenTool.active_path.is_clockwise ()) {
						ps = new PointSelection (PenTool.active_path.points.get (0), PenTool.active_path);
					} else {
						ps = new PointSelection (PenTool.active_path.points.get (PenTool.active_path.points.size - 1), PenTool.active_path);
					}
					
					PenTool.selected_points.clear ();
					PenTool.selected_points.add (ps);
					PenTool.selected_point = ps.point; 
					
					state = MOVE_LAST_HANDLE;
					
					if (one_point) {
						p.press_action (p, 2, x, y);
						state = NONE;
					}
				}
			} 
		}

		last_move_x = x;
		last_move_y = y;
	}
	
	public void stop_drawing () {
		PenTool p = (PenTool) PointTool.pen ();
		Path a;
		
		p.release_action (p, 1, last_move_x, last_move_y);

		if (state != NONE) {
			a = get_active_path ();
			if (a.is_open () && a.points.size > 0) {
				a.delete_last_point ();

				a.get_first_point ().set_reflective_handles (false);
				a.get_first_point ().set_tie_handle (false);

				a.get_last_point ().set_reflective_handles (false);
				a.get_last_point ().set_tie_handle (false);
			}
		}

		p.press_action (p, 2, last_move_x, last_move_y);
		p.release_action (p, 2, last_move_x, last_move_y);
		current_path.hide_end_handle = true;
		
		previous_point = 0;
		state = NONE;
		
		MainWindow.get_current_glyph ().clear_active_paths ();
		PenTool.active_path = new Path ();
	}
	
	public Path get_active_path () {
		Glyph g = MainWindow.get_current_glyph ();
		if (g.active_paths.size == 0) {
			return new Path ();
		}
		return g.active_paths.get (g.active_paths.size -1);
	}
	
	public void switch_to_line_mode () {
		EditPoint ep;
		EditPoint last;
		
		if (PenTool.active_path.points.size > 2) {
			ep = PenTool.active_path.points.get (PenTool.active_path.points.size - 2);
			ep.get_right_handle ().convert_to_line ();
			ep.set_tie_handle (false);
			
			last = PenTool.active_path.points.get (PenTool.active_path.points.size - 1);
			last.convert_to_line ();
			
			move_action (this, last_move_x, last_move_y);
		}
	}
	
	PointSelection add_new_point (int x, int y) {
		PointSelection last;
		double handle_x, handle_y;
		
		PenTool p = (PenTool) PointTool.pen ();
		
		if (PenTool.active_path.points.size == 0) {
			last = p.new_point_action (x, y);
		} else {			
			if (PenTool.selected_points.size == 0) {
				last = p.new_point_action (x, y);
			}
			
			if (PenTool.selected_points.size == 0) {
				warning ("No selected points.");
				return new PointSelection.empty ();
			}
			
			last = PenTool.selected_points.get (PenTool.selected_points.size - 1);
			
			PenTool.selected_points.clear ();
			PenTool.selected_handle = new EditPointHandle.empty ();
						
			if (DrawingTools.get_selected_point_type () != PointType.QUADRATIC) {
				last = p.new_point_action (x, y);
			} else {
				last.point.get_right_handle ().length *= 0.999999;
				handle_x = last.point.get_right_handle ().x;
				handle_y = last.point.get_right_handle ().y;
				
				last = p.new_point_action (x, y);
				
				last.point.get_left_handle ().x = handle_x;
				last.point.get_left_handle ().y = handle_y;
			}
			
			PenTool.move_selected = true;
			p.move_action (p, x, y);
		}
		
		PenTool.selected_points.clear ();
		PenTool.selected_points.add (last);	
		PenTool.selected_point = last.point; 
		PenTool.active_edit_point = null;
		PenTool.show_selection_box = false;
		
		PenTool.move_selected_handle = false;
		PenTool.move_selected = true;

		PenTool.active_path.hide_end_handle = (state == MOVE_POINT);
		
		current_path = last.path;
		
		return last;
	}
	
	// FIXME: solve the straight line issue in undo
	public override void before_undo () {
		EditPoint last;
		
		if (PenTool.active_path.points.size > 1) {
			last = PenTool.active_path.points.get (PenTool.active_path.points.size - 2);
			last.convert_to_curve ();
		}
	}
	
	public override void after_undo () {
		PenTool.selected_points.clear ();
		PenTool.active_edit_point = null;
		state = NONE;

		EditPoint last;
		
		if (PenTool.active_path.points.size > 0) {
			last = PenTool.active_path.points.get (PenTool.active_path.points.size - 1);
			last.convert_to_curve ();
		}
	}

}

}
