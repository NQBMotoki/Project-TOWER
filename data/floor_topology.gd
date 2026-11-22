extends RefCounted

# Each entry is center x/y followed by the obstacle's physical width/height.
# Ordered structural cover anchors the routes. The remaining slots draw from variations.
const STRUCTURE := {
	# F1: An open practice court framed by four corners.
	1: [Vector4i(370, 256, 46, 42), Vector4i(824, 256, 46, 42), Vector4i(400, 480, 46, 42)],
	# F2: Bunks flank a direct aisle with a walkway along each wall.
	2: [Vector4i(425, 258, 30, 135), Vector4i(425, 470, 30, 132),
		Vector4i(810, 258, 30, 135), Vector4i(810, 470, 30, 132)],
	# F3: Two staggered study benches turn the floor into an S-shaped route.
	3: [Vector4i(467, 274, 210, 32), Vector4i(830, 477, 210, 32),
		Vector4i(350, 458, 44, 42), Vector4i(982, 344, 44, 42), Vector4i(747, 181, 100, 30)],
	# F4: Offset firing lanes with open crossings on alternating ends.
	4: [Vector4i(344, 339, 34, 148), Vector4i(503, 417, 32, 148),
		Vector4i(765, 267, 34, 138), Vector4i(929, 418, 32, 134),
		Vector4i(668, 498, 97, 29), Vector4i(1008, 257, 44, 42)],
	# F5: Two long parapets frame the exposed guard chamber.
	5: [Vector4i(384, 227, 148, 32), Vector4i(813, 164, 153, 32)],
	# F6: Uneven tomb rows with a processional path beside them.
	6: [Vector4i(383, 256, 139, 33), Vector4i(411, 428, 143, 32),
		Vector4i(778, 252, 31, 135), Vector4i(810, 458, 28, 120)],
	# F7: A broken barricade steps across a diagonal retreat route.
	7: [Vector4i(359, 287, 126, 32), Vector4i(510, 393, 112, 28),
		Vector4i(761, 417, 121, 31), Vector4i(969, 501, 106, 28),
		Vector4i(921, 344, 45, 43)],
	# F8: The corners of the ritual chamber leave an open interior and flanking paths.
	8: [Vector4i(460, 259, 125, 32), Vector4i(790, 261, 113, 32),
		Vector4i(457, 490, 121, 32), Vector4i(738, 483, 111, 30),
		Vector4i(300, 352, 46, 44), Vector4i(993, 348, 46, 44)],
	# F9: Longer longitudinal cover creates bow lanes and several lateral breaks.
	9: [Vector4i(401, 267, 32, 152), Vector4i(402, 487, 33, 132),
		Vector4i(749, 251, 33, 140), Vector4i(883, 443, 33, 147),
		Vector4i(640, 495, 100, 30), Vector4i(1025, 352, 45, 43)],
	# F10: A largely unobstructed arena with isolated flanking pillars.
	10: [Vector4i(361, 222, 50, 48), Vector4i(823, 185, 50, 48)],
}

const VARIATIONS := {
	1: [Vector4i(750, 491, 45, 42), Vector4i(734, 527, 45, 42), Vector4i(1050, 350, 46, 42)],
	2: [Vector4i(696, 208, 46, 42), Vector4i(963, 352, 46, 42), Vector4i(314, 365, 40, 44)],
	3: [Vector4i(522, 482, 47, 44), Vector4i(628, 492, 46, 42), Vector4i(1032, 462, 44, 42)],
	4: [Vector4i(368, 508, 46, 43), Vector4i(207, 361, 46, 43), Vector4i(560, 244, 46, 43)],
	5: [Vector4i(478, 503, 124, 28), Vector4i(841, 507, 124, 28), Vector4i(365, 492, 68, 31)],
	6: [Vector4i(567, 539, 44, 42), Vector4i(1037, 328, 44, 42), Vector4i(243, 367, 46, 43)],
	7: [Vector4i(467, 538, 47, 43), Vector4i(692, 197, 47, 43), Vector4i(844, 208, 47, 43)],
	8: [Vector4i(1027, 470, 45, 42), Vector4i(770, 373, 45, 42), Vector4i(350, 147, 43, 44)],
	9: [Vector4i(592, 227, 46, 42), Vector4i(280, 421, 46, 42), Vector4i(1015, 485, 44, 43)],
	10: [Vector4i(438, 505, 140, 28), Vector4i(843, 507, 141, 28), Vector4i(957, 495, 58, 33)],
}

# Vignette anchor x/y and display width by floor. Upright assets share the
# nearest authored cover. Ritual and royal seal assets are floor inlays.
const VIGNETTES := [
	Vector3i(370, 256, 82), Vector3i(425, 470, 87), Vector3i(467, 274, 78),
	Vector3i(929, 418, 71), Vector3i(813, 164, 106), Vector3i(383, 256, 113),
	Vector3i(761, 417, 105), Vector3i(640, 258, 107), Vector3i(883, 443, 87),
	Vector3i(640, 287, 116),
]
const FLAT_VIGNETTES := [8, 10]
