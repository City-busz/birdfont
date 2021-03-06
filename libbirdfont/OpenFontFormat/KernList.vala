/*
	Copyright (C) 2014 Johan Mattsson

	This library is free software; you can redistribute it and/or modify 
	it under the terms of the GNU Lesser General Public License as 
	published by the Free Software Foundation; either version 3 of the 
	License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful, but 
	WITHOUT ANY WARRANTY; without even the implied warranty of 
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
	Lesser General Public License for more details.
*/

namespace BirdFont {

public class KernList : GLib.Object {
	public Gee.ArrayList<PairFormat1> pairs;

	public delegate void KernIterator (Kern k);
	public delegate void PairFormat1Iterator (PairFormat1 k);

	public GlyfTable glyf_table;
	public uint num_pairs;
	
	public KernList (GlyfTable glyf_table) {
		this.glyf_table = glyf_table;
		num_pairs = 0;
		pairs = new Gee.ArrayList<PairFormat1> (); 
	}
		
	/** @return number of pairs. */
	public uint fetch_all_pairs () {
		PairFormat1 current_pairs = new PairFormat1 ();
		KerningClasses classes;
		
		if (pairs.size > 0 || num_pairs > 0) {
			warning ("Pairs already loaded.");
		}
		
		num_pairs = 0;
		pairs.clear ();
		
		classes = BirdFont.get_current_font ().get_kerning_classes ();
		classes.all_pairs ((kp) => {
			uint16 gid_left, gid_right;
			KerningPair kerning_pair = kp;
			int i;
			
			if (unlikely (kerning_pair.character.get_name () == "")) {
				warning ("No name for glyph");
			}
			
			
			string glyph_name = kerning_pair.character.get_name ();
			current_pairs = new PairFormat1 ();
			gid_left = (uint16) glyf_table.get_gid (glyph_name);

			if (unlikely (gid_left == -1)) {
				warning("Ignoring kerning for missing character: $(glyph_name)");			
				return;
			}		
			
			current_pairs.left = gid_left;
			pairs.add (current_pairs);
			
			if (unlikely (kerning_pair.kerning.size == 0)) {
				warning (@"No kerning pairs for character (left): $(glyph_name)");
			}
			
			i = 0;
			num_pairs += kerning_pair.kerning.size;
			foreach (Kerning k in kerning_pair.kerning) {
				string right_name = k.get_glyph ().get_name ();
				gid_right = (uint16) glyf_table.get_gid (right_name);

				if (unlikely (gid_right == -1)) {
					warning("Ignoring kerning for missing character (right): $(right_name)");
				} else {
					int16 kerning_value = (int16) Math.rint (k.val * HeadTable.UNITS);
					Kern kern = new Kern (gid_left, gid_right, kerning_value);
					current_pairs.pairs.add (kern);
				}							
			}
			
			current_pairs.pairs.sort ((a, b) => {
				Kern first = (Kern) a;
				Kern next = (Kern) b;
				return first.right - next.right;
			});
		});
		
		pairs.sort ((a, b) => {
			PairFormat1 first = (PairFormat1) a;
			PairFormat1 next = (PairFormat1) b;
			return first.left - next.left;
		});
		
		return num_pairs;
	}

	/** @return the number of glyphs that is kerned on the left side in 
	 * pair pos format 1.
	 */
	public uint get_length_left () {
		return pairs.size;
	}
		
	/** @return the total number of pairs. */
	public uint get_length () {
		return num_pairs;
	}
	
	public void all_kern (KernIterator iter, int limit) {
		int i = 0;
		foreach (PairFormat1 p in pairs) {
			foreach (Kern k in p.pairs) {
				if (unlikely (i >= limit)) {
					warning (@"Too many pairs. Limit: $limit");
					return;
				}
				
				iter (k);
				i++;
			}
		}
	}

	public void all_pairs_format1 (PairFormat1Iterator iter, int limit = -1) {
		uint i = 0;
		
		foreach (PairFormat1 p in pairs) {
			if (unlikely (i >= limit && limit != -1)) {
				warning (@"Too many pairs. Limit: $limit");
				return;
			}
			
			iter (p);
			
			i++;
		}
	}
	
	public void all_single_kern (PairFormat1Iterator iter) {
		foreach (PairFormat1 p in pairs) {
			foreach (Kern k in p.pairs) {
				PairFormat1 single = new PairFormat1 ();
				single.left = p.left;
				single.pairs.add (k);
				
				iter (single);
			}
		}
	}
}

}
