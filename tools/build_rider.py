"""Original Terra MX rider. Run: blender -b --python tools/build_rider.py.
No downloaded meshes/textures. Mesh, materials, helmet, gear and rig authored here.
Blender metres: +Y forward, +Z up; glTF exporter converts to Godot -Z/+Y.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
root=Path(__file__).resolve().parents[1]

def material(name,color,rough=.7,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m
navy=material('Woven midnight jersey',(.025,.075,.11)); cream=material('Warm white fabric',(.85,.88,.83)); orange=material('Safety orange panels',(.95,.22,.035)); black=material('Rubber and flex panels',(.018,.025,.03),.85); boot=material('White boot armor',(.78,.82,.80),.4); visor=material('Goggle lens',(.025,.15,.20),.12,.65); shell=material('Helmet enamel',(.87,.89,.85),.32); dark=material('Helmet vents',(.012,.022,.027)); seam=material('Stitching',(.3,.38,.4))
# Each deform segment has a named anatomical bone. The rest pose is standing.
bones={
 'pelvis':((0,0,.96),(0,0,1.08),None),
 'spine':((0,0,1.08),(0,0,1.30),'pelvis'),
 'chest':((0,0,1.30),(0,0,1.48),'spine'),
 'neck':((0,0,1.48),(0,0,1.57),'chest'),
 'head':((0,0,1.57),(0,0,1.77),'neck')}
for suffix,sign in [('L',-1),('R',1)]:
 bones.update({
  'upper_arm.'+suffix:((sign*.20,0,1.45),(sign*.38,0,1.17),'chest'),
  'forearm.'+suffix:((sign*.38,0,1.17),(sign*.42,.025,.90),'upper_arm.'+suffix),
  'hand.'+suffix:((sign*.42,.025,.90),(sign*.42,.11,.84),'forearm.'+suffix),
  'thigh.'+suffix:((sign*.105,0,.96),(sign*.12,0,.52),'pelvis'),
  'shin.'+suffix:((sign*.12,0,.52),(sign*.12,0,.10),'thigh.'+suffix),
  'foot.'+suffix:((sign*.12,0,.10),(sign*.12,.18,.045),'shin.'+suffix)})
arm_data=bpy.data.armatures.new('TerraMX anatomical rig');arm=bpy.data.objects.new('RiderRig',arm_data);bpy.context.collection.objects.link(arm);bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for name,(a,b,parent) in bones.items():
 bone=arm_data.edit_bones.new(name);bone.head=a;bone.tail=b
 if parent: bone.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT');arm.select_set(False)

def bind(obj,bone,mat):
 obj.data.materials.append(mat)
 vg=obj.vertex_groups.new(name=bone);vg.add(list(range(len(obj.data.vertices))),1,'REPLACE')
 mod=obj.modifiers.new('Anatomical deformation','ARMATURE');mod.object=arm
 obj.parent=arm
 for p in obj.data.polygons: p.use_smooth=True
 return obj

def mesh(name,vertices,faces,bone,mat):
 data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update();obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
 return bind(obj,bone,mat)

def loft(name,centers,radii,bone,mat,sides=16):
 # Explicit cross-sections produce tapered anatomy and tailored clothing silhouettes.
 verts=[];faces=[]
 for i,center in enumerate(centers):
  c=Vector(center);direction=Vector(centers[min(i+1,len(centers)-1)])-Vector(centers[max(i-1,0)])
  direction.normalize();u=Vector((1,0,0));u=(u-direction*u.dot(direction)).normalized();v=direction.cross(u).normalized()
  for j in range(sides):
   a=j*math.tau/sides;verts.append(tuple(c+u*math.cos(a)*radii[i][0]+v*math.sin(a)*radii[i][1]))
 for i in range(len(centers)-1):
  for j in range(sides):
   a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
 faces.append(tuple(reversed(range(sides))));faces.append(tuple((len(centers)-1)*sides+j for j in range(sides)))
 return mesh(name,verts,faces,bone,mat)

def segment(name,a,b,radius,bone,mat):
 a=Vector(a);b=Vector(b)
 return loft(name,[a,a.lerp(b,.12),a.lerp(b,.5),a.lerp(b,.88),b],[(radius*.8,radius*.8),(radius,radius),(radius*.95,radius*.95),(radius*.72,radius*.72),(radius*.67,radius*.67)],bone,mat,12)

def box(name,center,size,bone,mat,bevel=.01):
 bpy.ops.mesh.primitive_cube_add(size=1,location=center);obj=bpy.context.object;obj.name=name;obj.dimensions=size
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 if bevel:
  mod=obj.modifiers.new('Tailored edge','BEVEL');mod.width=bevel;mod.segments=2
  bpy.ops.object.modifier_apply(modifier=mod.name)
 return bind(obj,bone,mat)

def text(name,value,location,size,bone,mat,front=False):
 bpy.ops.object.text_add(location=location);obj=bpy.context.object;obj.name=name;obj.data.body=value;obj.data.size=size;obj.data.extrude=.0008;obj.data.align_x='CENTER';obj.rotation_euler=(math.pi/2,0,math.pi if front else 0)
 bpy.ops.object.convert(target='MESH');obj=bpy.context.object;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);return bind(obj,bone,mat)

loft('Jersey waist to ribs',[(0,0,1.00),(0,0,1.10),(0,0,1.25),(0,0,1.33)],[(.135,.09),(.15,.10),(.165,.105),(.18,.105)],'spine',navy)
loft('Tailored shoulders',[(0,0,1.28),(0,0,1.37),(0,0,1.44),(0,0,1.48)],[(.17,.105),(.205,.115),(.23,.10),(.10,.065)],'chest',navy)
loft('Balaclava neck',[(0,0,1.50),(0,0,1.55),(0,0,1.61)],[(.061,.052),(.059,.05),(.058,.05)],'neck',black)
loft('Collar',[(0,0,1.46),(0,0,1.50),(0,0,1.53)],[(.08,.065),(.075,.06),(.065,.055)],'neck',black)
loft('Pant hip panels',[(0,0,.90),(0,0,.96),(0,0,1.025)],[(.155,.10),(.17,.105),(.14,.09)],'pelvis',navy)
box('Jersey back yoke',(0,-.105,1.43),(.34,.018,.055),'chest',cream,.008)
text('Race number back','27',(0,-.118,1.24),.17,'chest',cream)
text('Rider name back','TERRA',(0,-.12,1.42),.045,'chest',orange)
text('Race number chest','27',(0,.118,1.34),.11,'chest',cream,True)
for suffix,sign in [('L',-1),('R',1)]:
 upper='upper_arm.'+suffix;fore='forearm.'+suffix;hand='hand.'+suffix;thigh='thigh.'+suffix;shin='shin.'+suffix;foot='foot.'+suffix
 a,b,_=bones[upper];segment('Jersey upper sleeve '+suffix,a,b,.079,upper,navy)
 a,b,_=bones[fore];segment('Jersey fore sleeve '+suffix,a,b,.057,fore,cream)
 c=Vector(a).lerp(Vector(b),.55);segment('Sleeve orange band '+suffix,c,c+(Vector(b)-Vector(a))*.2,.058,fore,orange)
 a,b,_=bones[hand];segment('Glove '+suffix,a,b,.047,hand,black)
 box('Glove knuckle guard '+suffix,(sign*.42,-.018,.888),(.075,.025,.07),hand,orange,.01)
 segment('Glove thumb '+suffix,(sign*.405,.035,.88),(sign*.39,.095,.87),.019,hand,black)
 a,b,_=bones[thigh];segment('Race pant thigh '+suffix,a,b,.095,thigh,navy)
 segment('Outer thigh stripe '+suffix,(sign*.178,-.002,.88),(sign*.185,-.002,.63),.018,thigh,orange)
 a,b,_=bones[shin];segment('Flex pant knee and shin '+suffix,a,b,.065,shin,black)
 box('Knee armor '+suffix,(sign*.12,.057,.51),(.11,.04,.12),shin,cream,.025)
 # A tall molded boot, shaped ankle and extended toe, rather than a capsule foot.
 loft('Boot shaft '+suffix,[(sign*.12,0,.08),(sign*.12,0,.15),(sign*.12,0,.30),(sign*.12,0,.39)],[(.068,.08),(.06,.07),(.075,.08),(.074,.075)],shin,boot,12)
 box('Boot toe '+suffix,(sign*.12,.085,.055),(.145,.28,.10),foot,boot,.025)
 box('Boot sole '+suffix,(sign*.12,.085,.015),(.15,.285,.025),foot,black,.008)
 box('Shin plate '+suffix,(sign*.12,.077,.28),(.10,.025,.18),shin,cream,.012)
 for h in [.15,.23,.32]:
  box('Boot buckle strap '+suffix,(sign*.12,-.077,h),(.13,.015,.018),shin,black,.004)
  box('Boot buckle '+suffix,(sign*.178,-.062,h),(.025,.04,.027),shin,orange,.004)
# Helmet: custom crown profile, goggle opening, chin guard and extended peak.
loft('Helmet crown',[(0,-.01,1.58),(0,-.02,1.65),(0,-.025,1.74),(0,-.025,1.81),(0,-.025,1.845)],[(.10,.09),(.135,.13),(.14,.14),(.105,.11),(.015,.025)],'head',shell,24)
# Helmet side graphics, mouthpiece and protective chin bridge.
for sign in [-1,1]:
 segment('Helmet side jaw',(sign*.11,.055,1.65),(sign*.085,.19,1.59),.025,'head',orange)
 box('Helmet jaw vent',(sign*.105,.13,1.62),(.015,.065,.025),'head',dark,.004)
 box('Helmet temple decal',(sign*.137,-.005,1.72),(.009,.10,.045),'head',orange,.004)
box('Chin bar',(0,.192,1.60),(.17,.065,.065),'head',shell,.018)
box('Mouth vent',(0,.227,1.61),(.105,.012,.028),'head',dark,.006)
# Goggles curved across the face, continuous frame and smoked lens.
verts=[];faces=[]
for z in [1.665,1.722]:
 for j in range(13):
  angle=-.9+j*1.8/12;verts.append((math.sin(angle)*.145,.09+math.cos(angle)*.092,z))
for j in range(12): faces.append((j,j+1,j+14,j+13))
mesh('Curved goggle lens',verts,faces,'head',visor)
for z in [1.66,1.727]:
 for j in range(12): segment('Goggle frame',verts[j] if z<1.7 else verts[j+13],verts[j+1] if z<1.7 else verts[j+14],.008,'head',orange)
for sign in [-1,1]: segment('Goggle side frame',(sign*.113,.147,1.66),(sign*.113,.147,1.73),.01,'head',black)
loft('Goggle strap',[(0,-.025,1.675),(0,-.025,1.708)],[(.139,.14),(.139,.14)],'head',black,24)
# Wide, deliberately motocross-shaped peaked visor.
verts=[(-.13,.01,1.77),(.13,.01,1.77),(.155,.22,1.785),(.09,.32,1.77),(-.09,.32,1.77),(-.155,.22,1.785)]
verts += [(x,y,z-.012) for x,y,z in verts]
faces=[tuple(range(6)),tuple(reversed(range(6,12)))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
mesh('Motocross visor peak',verts,faces,'head',orange)
for sign in [-1,1]: box('Crown cooling vent',(sign*.055,.02,1.816),(.025,.09,.009),'head',dark,.005)
# Export the authored rest mesh + actual armature skin. No external assets are used.
bpy.ops.object.select_all(action='DESELECT')
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for obj in meshes: obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.join()
bpy.context.object.name='Terra_Rider_Skinned_Gear'
arm.select_set(True)
output=root/'assets/rider/terra_rider.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_animations=False,export_skins=True,export_yup=True)
print('RIDER_ASSET',output,'bones',len(bones),'mesh_objects',sum(o.type=='MESH' for o in bpy.data.objects))
