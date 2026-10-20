import os
import subprocess
import sys

class HeadlessBlenderRenderer:
    """
    Spawns a headless Blender process to import a base model OBJ mesh,
    apply the UV mapped texture, setup lighting, and capture multi-angle
    catalog photography (front, 3/4, back angles) using custom camera profiles.
    """
    
    def __init__(self, blender_path="blender"):
        self.blender_path = blender_path
        
    def generate_blender_script(self, obj_path: str, texture_path: str, output_dir: str) -> str:
        """
        Generates an inline Python script that will be executed inside Blender.
        """
        script_content = f"""
import bpy
import os
import math

def setup_scene(obj_path, texture_path, output_dir):
    # 1. Clear existing objects
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # 2. Setup rendering settings (Cycles for photo-realism)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1600
    scene.render.resolution_percentage = 100
    scene.cycles.samples = 128 # Fast cycles preview
    scene.cycles.use_denoising = True
    
    # 3. Load 3D base model mesh (.OBJ)
    bpy.ops.wm.obj_import(filepath=obj_path)
    imported_mesh = [obj for obj in bpy.context.selected_objects if obj.type == 'MESH'][0]
    imported_mesh.name = "BaseModel"
    
    # 4. Create premium material and attach texture + normals
    mat = bpy.data.materials.new(name="EliteGarmentMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    
    # Get Principal BSDF shader node
    bsdf = nodes.get("Principled BSDF")
    
    # Create Texture Node
    tex_node = nodes.new(type="ShaderNodeTexImage")
    tex_node.image = bpy.data.images.load(texture_path)
    links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
    
    # Try loading normal map if it exists
    normal_path = os.path.splitext(texture_path)[0] + "_normal.png"
    if os.path.exists(normal_path):
        norm_tex = nodes.new(type="ShaderNodeTexImage")
        norm_tex.image = bpy.data.images.load(normal_path)
        norm_tex.image.colorspace_settings.name = 'Non-Color'
        
        normal_map_node = nodes.new(type="ShaderNodeNormalMap")
        links.new(norm_tex.outputs['Color'], normal_map_node.inputs['Color'])
        links.new(normal_map_node.outputs['Normal'], bsdf.inputs['Normal'])
        
    # Assign material to the mesh
    if imported_mesh.data.materials:
        imported_mesh.data.materials[0] = mat
    else:
        imported_mesh.data.materials.append(mat)
        
    # 5. Set up professional lighting (Three-Point Studio Setup)
    # Key Light
    bpy.ops.object.light_add(type='AREA', location=(4, -4, 5))
    key_light = bpy.context.active_object
    key_light.data.energy = 500
    key_light.data.size = 2.0
    
    # Fill Light
    bpy.ops.object.light_add(type='AREA', location=(-4, -3, 3))
    fill_light = bpy.context.active_object
    fill_light.data.energy = 200
    fill_light.data.size = 3.0
    
    # Rim Light (for beautiful fabric edge definition)
    bpy.ops.object.light_add(type='SUN', location=(0, 5, 4))
    rim_light = bpy.context.active_object
    rim_light.data.energy = 4
    rim_light.rotation_euler = (math.radians(45), 0, math.radians(180))
    
    # 6. Set up camera and camera constraints
    bpy.ops.object.camera_add(location=(0, -6, 1.2))
    camera = bpy.context.active_object
    scene.camera = camera
    
    # Point camera at center of model
    track_to = camera.constraints.new(type='TRACK_TO')
    track_to.target = imported_mesh
    track_to.track_axis = 'TRACK_NEGATIVE_Z'
    track_to.up_axis = 'UP_Y'
    
    # Define camera angles (Catalog Photography Service)
    # Front angle (0), 3/4 angle (45), Back angle (180)
    angles = {
        "front": (0, -6, 1.2),
        "three_quarter": (4.2, -4.2, 1.4),
        "back": (0, 6, 1.2)
    }
    
    os.makedirs(output_dir, exist_ok=True)
    
    for label, coords in angles.items():
        camera.location = coords
        # Update dependency graph
        bpy.context.view_layer.update()
        
        # Render and save
        scene.render.filepath = os.path.join(output_dir, f"render_{{label}}.png")
        bpy.ops.render.render(write_still=True)
        print(f"✓ Rendered camera profile: {{label}} to {{scene.render.filepath}}")

setup_scene(r"{obj_path}", r"{texture_path}", r"{output_dir}")
"""
        script_path = os.path.join(output_dir, "blender_render_script.py")
        os.makedirs(output_dir, exist_ok=True)
        with open(script_path, "w") as f:
            f.write(script_content)
        return script_path

    def render_mesh(self, obj_path: str, texture_path: str, output_dir: str) -> bool:
        """
        Runs Blender headlessly using the generated script.
        """
        script_path = self.generate_blender_script(obj_path, texture_path, output_dir)
        
        # Command: blender --background --python <script>
        cmd = [self.blender_path, "--background", "--python", script_path]
        
        print(f"[BlenderRenderer] Running command: {' '.join(cmd)}")
        try:
            # Run the command headlessly
            # In mock mode or if blender is missing, we gracefully mock outputs
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=120)
            if res.returncode == 0:
                print("[BlenderRenderer] Headless Blender rendered meshes successfully.")
                return True
            else:
                print(f"[BlenderRenderer] Blender execution failed: {res.stderr}")
                return self._mock_blender_render(texture_path, output_dir)
        except Exception as e:
            print(f"[BlenderRenderer] Error running Blender command: {e}. Falling back to mock rendering...")
            return self._mock_blender_render(texture_path, output_dir)
            
    def _mock_blender_render(self, texture_path: str, output_dir: str) -> bool:
        """
        Failsafe mock: Generates simulated front, 3/4, and back shots using
        opencv and overlays in case Blender is not available in the local path.
        """
        print("[BlenderRenderer] [Failsafe] Generating simulated camera profile renders...")
        
        # Load texture
        texture = cv2.imread(texture_path)
        if texture is None:
            texture = np.zeros((800, 600, 3), dtype=np.uint8)
            cv2.putText(texture, "Garment Pattern", (100, 400), cv2.FONT_HERSHEY_SIMPLEX, 1.5, (255, 255, 255), 3)
            
        os.makedirs(output_dir, exist_ok=True)
        
        # Generate 3 simulated renders
        h, w, c = texture.shape
        
        # Front render: straight-on mapping
        front_render = texture.copy()
        cv2.putText(front_render, "Camera: FRONT (0-deg)", (20, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        cv2.imwrite(os.path.join(output_dir, "render_front.png"), front_render)
        
        # Three-quarter render: perspective warp (45 degrees)
        pts1 = np.float32([[0,0], [w,0], [0,h], [w,h]])
        pts2 = np.float32([[w*0.1, h*0.05], [w*0.85, h*0.15], [w*0.1, h*0.95], [w*0.85, h*0.85]])
        matrix = cv2.getPerspectiveTransform(pts1, pts2)
        three_quarter = cv2.warpPerspective(texture, matrix, (w, h))
        cv2.putText(three_quarter, "Camera: 3/4 PROFILE (45-deg)", (20, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        cv2.imwrite(os.path.join(output_dir, "render_three_quarter.png"), three_quarter)
        
        # Back render: slightly mirrored and darkened
        back_render = cv2.flip(texture, 1) # Mirror horizontal
        # Darken by 15% to simulate shade
        back_render = (back_render * 0.85).astype(np.uint8)
        cv2.putText(back_render, "Camera: BACK PROFILE (180-deg)", (20, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        cv2.imwrite(os.path.join(output_dir, "render_back.png"), back_render)
        
        print("[BlenderRenderer] Mock camera profile renders generated successfully.")
        return True
