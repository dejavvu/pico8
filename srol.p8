pico-8 cartridge // http://www.pico-8.com
version 15
__lua__

-- constants

dithering_masks = {
 0b1111111111111111,
 0b0111111111111111,
 0b0111111111011111,
 0b0101111111011111,
 0b0101111101011111,
 0b0101101101011111,
 0b0101101101011110,
 0b0101101001011110,
 0b0101101001011010,
 0b0001101001011010,
 0b0001101001001010,
 0b0000101001001010,
 0b0000101000001010,
 0b0000001000001010,
 0b0000001000001000,
 0b0000000000000000,
 -- mirror
 0b0000000000000000,
 0b0000001000001000,
 0b0000001000001010,
 0b0000101000001010,
 0b0000101001001010,
 0b0001101001001010,
 0b0001101001011010,
 0b0101101001011010,
 0b0101101001011110,
 0b0101101101011110,
 0b0101101101011111,
 0b0101111101011111,
 0b0101111111011111,
 0b0111111111011111,
 0b0111111111111111,
 0b1111111111111111,
}

palettes = {
 green = {
  bg = 0x03,
  fg = 0x0b
 },
 purple = {
  bg = 0x12,
  fg = 0x0d
 },
 red = {
  bg = 0x28,
  fg = 0x09
 },
 red2 = {
  bg = 0x08,
  fg = 0x09
 },
 blue = {
  bg = 0x1d,
  fg = 0x6,
 },
 bw = {
  snow = {0, 5, 6, 7}
 }
}

-- 3d math

scene_cam = {0, 0, -2.5, 80}
__debug_render_lines = true


function rotate_x(x, y, z, angle)
 local co, si = cos(angle), sin(angle)
 return {
  x,
  y*co - z*si,
  y*si + z*co
 }
end

function rotate_y(x, y, z, angle)
 local co, si = cos(angle), sin(angle)
 return {
  z*si + x*co,
  y,
  z*co - x*si
 }
end

function rotate_z(x, y, z, angle)
 local co, si = cos(angle), sin(angle)
 return {
  x*co - y*si,
  x*si + y*co,
  z
 }
end

function rotatev_x(v, angle)
 return rotate_x(v[1], v[2], v[3], angle)
end

function rotatev_y(v, angle)
 return rotate_y(v[1], v[2], v[3], angle)
end

function rotatev_z(v, angle)
 return rotate_z(v[1], v[2], v[3], angle)
end

function addv(v1, v2)
 return {v1[1]+v2[1], v1[2]+v2[2], v1[3]+v2[3]}
end

function subv(v1, v2)
 return {v1[1]-v2[1], v1[2]-v2[2], v1[3]-v2[3]}
end

function scalev(v, vs)
 return {v[1]*vs[1], v[2]*vs[2], v[3]*vs[3]}
end

function normv(v)
 local s = 1/sqrt(sqr(v[1])+sqr(v[2])+sqr(v[3]))
 return {v[1]*s, v[2]*s, v[3]*s}
end

function projectv(v)
 return project(v[1], v[2], v[3])
end

function distv(v1, v2)
 return sqrt(sqr(v1[1]-v2[1])+sqr(v1[2]-v2[2])+sqr(v1[3]-v2[3]))
end

function project(x, y, z)
 local d = z - scene_cam[3]
 local mult = scene_cam[4] / d
 local px = 64 + x * mult
 local py = 64 - y * mult
 return {x=px, y=py}
end

function sqr(x)
 return x*x
end

--

function sample(ary)
 return ary[1 + rnd(#ary - 1)]
end

-- 3d engine

function new_mesh()
 return {
  vertices = {},
  points = {},
  edges = {},
  vertex_transform = vertex_transform_identity
 }
end

function zfun_zero(x, y)
 return 0
end

function generate_plane_mesh(n, s, zfun)
 local mesh = new_mesh()
 local hn = n / 2
 local offset = 0
 for i=0,n do
  local y = i-hn
  for j=0,n do
   local x = j-hn
   local vertex = {x * s, y * s, zfun(x, y) * s}
   add(mesh.vertices, vertex)
   add(mesh.points, projectv(vertex))
   if j > 0 and i < n then
    add(mesh.edges, {offset, offset+1})
    add(mesh.edges, {offset, offset+n+1})
    add(mesh.edges, {offset+1, offset+n+2})
    add(mesh.edges, {offset+n+1, offset+n+2})
   end
   offset += 1
  end
 end

 return mesh
end

function generate_lhc_mesh(irad, orad, depth)
 local mesh = new_mesh()

 local fz = -depth/2
 local bz = depth/2

 local offset = 1
 for a=0,7 do
  local a1 = (a*0.125)-(0.0625/2)
  local a2 = (a*0.125)+(0.0625/2)
  local x1 = cos(a1)
  local y1 = sin(a1)
  local x2 = cos(a2)
  local y2 = sin(a2)
  -- front
  add(mesh.vertices, {x1*orad, y1*orad, fz})
  add(mesh.vertices, {x2*orad, y2*orad, fz})
  add(mesh.vertices, {x2*irad, y2*irad, fz})
  add(mesh.vertices, {x1*irad, y1*irad, fz})
  -- back
  add(mesh.vertices, {x1*orad, y1*orad, bz})
  add(mesh.vertices, {x2*orad, y2*orad, bz})
  add(mesh.vertices, {x2*irad, y2*irad, bz})
  add(mesh.vertices, {x1*irad, y1*irad, bz})
  -- edges front
  add(mesh.edges, {offset, offset+1})
  add(mesh.edges, {offset+1, offset+2})
  add(mesh.edges, {offset+2, offset+3})
  add(mesh.edges, {offset+3, offset})
  -- edges back
  add(mesh.edges, {offset+4, offset+4+1})
  add(mesh.edges, {offset+4+1, offset+4+2})
  add(mesh.edges, {offset+4+2, offset+4+3})
  add(mesh.edges, {offset+4+3, offset+4})
  -- edges sides
  add(mesh.edges, {offset, offset+4})
  add(mesh.edges, {offset+1, offset+4+1})
  add(mesh.edges, {offset+2, offset+4+2})
  add(mesh.edges, {offset+3, offset+4+3})
  -- dummy points
  for i=1,8 do
   add(mesh.points, {x=0, y=0})
  end

  offset += 8
 end

 return mesh
end

function generate_cylinder_mesh(nv, nh, s)
 local mesh = new_mesh()

 for i=0,(nv-1) do
  local y = (0.5-i*(1/nv)) * s[2]
  if false and (i == 0 or i == (nv-1)) then
   sx = 0.5
   sz = 0.5
  else
   sx = s[1]
   sz = s[3]
  end
  for j=0,(nh-1) do
   local a = j * (1/nh)
   add(mesh.vertices, {cos(a)*sx, y, sin(a)*sz})
   add(mesh.points, {x=0, y=0})
  end
 end

 for i=1,nv do
  for j=1,nh do
  local offset = (i-1) * nh
   add(mesh.edges, {offset+j, offset+(j%nh)+1})
   if (i > 1) then
    add(mesh.edges, {offset+j-nh, offset+j})
   end
  end
 end

 return mesh
end

function vertex_transform_identity(t, _i, v)
 return v
end

function vertex_transform_wave(t, i, v)
 local x = (3.5 - (i % 7)) * 0.5
 local y = (3.5 - (i / 7)) * 0.5
 local z = sin(x+t*0.5) * sin(y+t*0.5) * 0.5
 return rotatev_z(rotatev_x(rotatev_y({v[1], v[2], z}, t*0.1), -.1), 0)
end


function transform_mesh(mesh, timer)
 for idx = 1,#mesh.vertices do
  mesh.points[idx] = projectv(mesh.vertex_transform(timer, idx, mesh.vertices[idx]))
 end
end

function render_mesh(mesh, curpal)
 if __debug_render_lines then
  for edge in all(mesh.edges) do
   local p1 = mesh.points[edge[1]]
   local p2 = mesh.points[edge[2]]
   line(p1.x, p1.y, p2.x, p2.y, curpal.fg)
  end
 end

 -- highlight points
 for p in all(mesh.points) do
  pset(p.x, p.y, 7)
 end
end

-- helpers

function flipcol(col)
 return bor(shl(band(col, 15), 4), shr(col, 4))
end

function draw_dithered_background(col, timer)
 local loc = flipcol(col)
 local d = 8

 local idx = flr(timer + 100*sin(timer*0.025) + 50*sin(timer*0.05))

 for y=0,(128-d),d do
  local mask = dithering_masks[1+(idx%#dithering_masks)]
  fillp(mask)
  rectfill(0, y, 127, y+d, col)
  idx += 1
 end

 fillp(0)
end

function centered_text_lines(lines)
 local h = #lines * 8
 local y = 64 - h / 2
 for text in all(lines) do
  centered_text_line(text, y)
  y += 8
 end
end


function centered_text_line(text, y)
 local x = 64 - #text * 2
 print(text, x-1, y-1, 0)
 print(text, x,   y-1, 0)
 print(text, x+1, y-1, 0)

 print(text, x-1, y, 0)
 print(text, x+1, y, 0)

 print(text, x-1, y+1, 0)
 print(text, x,   y+1, 0)
 print(text, x+1, y+1, 0)

 print(text, x, y, 7)
end

-- parts

function part_wave_update(t)
 transform_mesh(wave_mesh, t)
end

function part_wave_draw()
 local mypal = palettes.blue
 draw_dithered_background(mypal.bg, timer)
 render_mesh(wave_mesh, mypal)
end

function part_cylinder_update(t)
 transform_mesh(cylinder_mesh, t)
end

function part_cylinder_draw()
 local mypal = palettes.red
 draw_dithered_background(mypal.bg, timer)
 render_mesh(cylinder_mesh, mypal)
end

function part_lhc_update(t)
 transform_mesh(lhc_mesh, t)
end

function part_lhc_draw()
 local mypal = palettes.green
 draw_dithered_background(mypal.bg, timer)
 render_mesh(lhc_mesh, mypal)
end

function part_trench_update(t)
 transform_mesh(trench_mesh, t)
end

function part_trench_draw()
 local mypal = palettes.green
 draw_dithered_background(mypal.bg, timer)
 render_mesh(trench_mesh, mypal)
end

credits_screen_index = 1

function part_credits_update(t)
 credits_screen_index = 1 + (flr(t*0.25) % #credits_screens)
end

credits_screens = {
 {
  "forever loving robot",
  "",
  "is the",
  "human robot of love"

 },
 {
  "unconditional love to",
  "",
  "dune",
  "hoplite",
  "der pippoo",
  "",
  "the robots in their teens"
 },
 {
  "nooon",
  "complex",
  "melon",
  "polka brothers"
 },
 {
  "pico-8 demake",
  "",
  "by",
  "@xavierdefrang",
  "",
  "2018 is the new 1995"
 }
}

function part_credits_draw()

 -- snow
 for y=0,63 do
  for x=0,63 do
   local col=5+rnd(3)
   pset(x, y, col)
   pset(x+64, y, col)
   pset(x, y+64, col)
   pset(x+64, y+64, col)
  end
 end

 --
 centered_text_lines(credits_screens[credits_screen_index])
end

parts = {
 {part_cylinder_update, part_cylinder_draw},
 {part_wave_update, part_wave_draw},
 {part_lhc_update, part_lhc_draw},
 {part_trench_update, part_trench_draw},
 {part_credits_update, part_credits_draw},
}

part_index = 1

-- main

function _init()
 timer = 0
 part_index = 1

 wave_mesh = generate_plane_mesh(7, 0.3, zfun_zero)
 wave_mesh.vertex_transform = vertex_transform_wave

 lhc_mesh = generate_lhc_mesh(1.5, 3, 1)
 lhc_mesh.vertex_transform = function (t, i, v)
  return addv(rotatev_y(v, t*0.5), {0, 0, 5})
 end

 local nh = 12
 local nv = 9
 cylinder_mesh = generate_cylinder_mesh(nv, nh, {2.5, 7, 2.5})
 cylinder_mesh.vertex_transform = function (t, i, v)
  local wave = sin(t*0.5)
  local y = (i/nh)
  local wavelet = cos(t*0.8+(y/nv)*2)
  local warp = {
   1+.5*wavelet,
   1+0.25*wavelet,
   1+.2*wavelet
  }
  return addv(
   rotatev_z(
    rotatev_y(
     scalev(v, warp),
     t*0.1
    ),
    0.03 * sin(t*0.2)
   ),
   {0, 0, 5}
  )
 end


 zfun_landscape = function(x, y)
  return 5*sin(x*0.1)*sin(y*0.1)
 end

 trench_mesh = generate_plane_mesh(12, 0.2, zfun_landscape)
 trench_mesh.vertex_transform = function (t, i, v)
  return rotatev_y(rotatev_x(v, -0.15), t*0.1)
 end

end

function _update()
 timer += 0.0333333
 printh("t="..timer.." pi="..part_index)
 parts[part_index][1](timer)

 if part_index > 1 and btnp(0) then
  part_index -= 1
 end

 if part_index < #parts and btnp(1) then
  part_index += 1
 end

 if btnp(4) then
  __debug_render_lines = not __debug_render_lines
 end
 if btnp(5) then
  -- other flag ...
 end


end

function _draw()
 parts[part_index][2]()
end
