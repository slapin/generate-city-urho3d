#include "Scripts/Createmodels.as"
#include "Scripts/FacadeRect.as"

enum facade_types {
    ITEM_FACADE,
    ITEM_FLOOR,
    ITEM_SOLID,
    ITEM_WINDOW_BLOCK,
};
class FacadeChunk {
    FacadeRect rect;
    int type;
    Vector2 size {
        get {
          return rect.size;
        }
    };
    String ToString()
    {
       String ret = "type: ";
       ret += String(type);
       ret += " rect: ";
       ret += rect.ToString();
       return ret;
    }
}
const float min_floor_height = 2.5;
const float min_solid_width = 20.0;
const float min_window_width = 1.8;
class Facade : ScratchModel {
    float width;
    float height;
    float depth;
    Array<FacadeChunk> queue = {};
    Array<FacadeChunk> result = {};
    void add(int t, FacadeRect r)
    {
        FacadeChunk v;
        v.type = t;
        v.rect = r;
        queue.Push(v);
    }
    void add_obj(Array<FacadeChunk> @obj, int t, FacadeRect r)
    {
        FacadeChunk v;
        v.type = t;
        v.rect = r;
        obj.Push(v);
    }
    void add_result(int t, FacadeRect r)
    {
        FacadeChunk v;
        v.type = t;
        v.rect = r;
        result.Push(v);
    }
    FacadeChunk fetch()
    {
        FacadeChunk v = queue[0];
        queue.Erase(0);
        return v;
    }
    Array<FacadeRect> vsplit2_rect(FacadeRect r, float b)
    {
        Array<FacadeRect> ret = r.split2t(b);
        return ret;
    }
    Array<FacadeChunk> vsplit2(int ltype, int rtype, float b, FacadeChunk r)
    {
        Array<FacadeChunk> ret;
        Array<FacadeRect> data = vsplit2_rect(r.rect, b);
        add_obj(ret, ltype, data[0]);
        add_obj(ret, rtype, data[1]);
        return ret;
    }
    Array<FacadeRect> hsplit2_rect(FacadeRect r, float b)
    {
        Array<FacadeRect> ret = r.split2l(b);
        return ret;
    }
    Array<FacadeChunk> hsplit2(int ltype, int rtype, float b, FacadeChunk r)
    {
        Array<FacadeChunk> ret;
        Array<FacadeRect> data = hsplit2_rect(r.rect, b);
        add_obj(ret, ltype, data[0]);
        add_obj(ret, rtype, data[1]);
        return ret;
    }
    Array<FacadeRect> hsplit3(FacadeRect rect, float l, float r)
    {
        Array<FacadeRect> ret;
        Array<FacadeRect> ret1 = rect.split2l(l);
        Array<FacadeRect> ret2 = ret1[1].split2r(r);
        ret.Push(ret1[0]);
        ret.Push(ret2[0]);
        ret.Push(ret2[1]);
        return ret;
    }
    Array<FacadeChunk> hsplit3(int icenter_type, int iside_type, float d, FacadeChunk r)
    {
        Array<FacadeChunk> ret;
        Array<FacadeRect> data = hsplit3(r.rect, d, d);
        add_obj(ret, iside_type, data[0]);
        add_obj(ret, icenter_type, data[1]);
        add_obj(ret, iside_type, data[2]);
        return ret;
    }
    Array<FacadeChunk> grow(FacadeChunk c)
    {
        Array<FacadeChunk> ret;
        Array<FacadeChunk> data;
        switch(c.type) {
        case ITEM_FACADE:
            if (c.rect.can_vsplit(min_floor_height))
                ret = vsplit2(ITEM_FLOOR, ITEM_FACADE, min_floor_height, c);
            else
                add_obj(ret, ITEM_FLOOR, c.rect);
            break;
        case ITEM_FLOOR:
            if (c.rect.can_hsplit(min_solid_width))
                ret = hsplit2(ITEM_SOLID, ITEM_FLOOR, min_solid_width, c);
            else {
                add_obj(ret, ITEM_SOLID, c.rect);
            }
            break;
/*
        case ITEM_SOLID:
            if (c.rect.can_hsplit(min_window_width * 2)) {
                ret = hsplit3(ITEM_WINDOW_BLOCK,
                    ITEM_SOLID,
                    int(c.rect.size.x / min_window_width) *
                        min_window_width, c);
            }
            break;
*/
        }
        return ret;
    }
    Node@ create_window()
    {
        Node@ ret = Node();
        Model@ win_model = cache.GetResource("Model", "Models/window/window1.mdl");
        // Material@ win_mat1 = cache.GetResource("Material", "Models/window/window-frame.xml");
        Material@ win_mat1 = Material();
        // Material@ win_mat2 = cache.GetResource("Material", "Models/window/glass.xml");
        Material@ win_mat2 = Material();
        win_mat1.SetTechnique(0, cache.GetResource("Technique", "Techniques/NoTexture.xml"));
        win_mat1.shaderParameters["MatDiffColor"] =  Variant(Vector4(0.166, 0.006, 0.0056, 1.0));
        win_mat1.shaderParameters["MatSpecColor"] =  Variant(Vector4(0.08, 0.08, 0.08, 8.0));
        win_mat2.SetTechnique(0, cache.GetResource("Technique", "Techniques/NoTexture.xml"));
        win_mat2.shaderParameters["MatDiffColor"] =  Variant(Vector4(0.64, 0.64, 0.64, 0.3));
        win_mat2.shaderParameters["MatSpecColor"] =  Variant(Vector4(0.3, 0.3, 0.3, 8.0));
        StaticModel@ obj = ret.CreateComponent("StaticModel");
        obj.model = win_model;
        // obj.materials[0] =  win_mat1;
        // obj.materials[1] = win_mat2;
        obj.occluder = true;
        obj.occludee = true;
//        RigidBody@ body = ret.CreateComponent("RigidBody");
//        CollisionShape@ shape = ret.CreateComponent("CollisionShape");
        BoundingBox bbox = win_model.boundingBox;
        Vector3 sz = bbox.size, pos = bbox.center;
//        shape.SetBox(sz, pos);
//        body.collisionLayer = 2;
//        body.collisionMask = 2;
        return ret;
    }
    Facade(float w, float h, float d, Material@ mat)
    {
        width = w;
        height = h;
        depth = d;
        add(ITEM_FACADE, FacadeRect(-w / 2.0 + d, 0.0, w / 2.0 - d, h));
        while(!queue.empty) {
            FacadeChunk item = fetch();
            int item_type = item.type;
            FacadeRect item_rect = item.rect;
            Array<FacadeChunk>@ newchunks = grow(item);
            if (newchunks.length != 0) {
                for (int i = 0; i < newchunks.length; i++)
                    queue.Push(newchunks[i]);
            } else
                // finals
                add_result(item_type, item_rect);
        }
        Vector3 offt;
        for (int i = 0; i < result.length; i++) {
            offt = Vector3(result[i].rect.left + result[i].rect.size.x / 2.0 , result[i].rect.top, 0.0);
            switch(result[i].type) {
            case ITEM_SOLID:
                add_quad0(result[i].rect.size.x,
                    result[i].rect.size.y, -depth, offt);
                add_quad1(result[i].rect.size.x,
                    result[i].rect.size.y, 0.0, offt);
                if (result[i].rect.size.y >= min_floor_height) {
                    Node@ win = create_window();
                    node.AddChild(win);
                    win.position = offt + Vector3(0.0, result[i].rect.size.y / 2.0 - 0.6 /* hack!!! */, 0.0);
                    win.rotation = Quaternion(0.0, 90, 0.0);
                }
                break;
            }
        }
        add_quad1(d, h, 0.0, Vector3(-w/2.0 + d/2.0, 0.0, 0.0));
        add_quad1(d, h, 0.0, Vector3(w/2.0 - d/2.0, 0.0, 0.0));

        bbox = BoundingBox(Vector3(-w/2 - 0.01, -0.01,  -d/2.0 - 0.01), Vector3(w/2 + 0.01, h + 0.01, d/2.0 + 0.01));
        create();
        // object.material = mat;
        object.castShadows = true;
        object.occluder = true;
        object.occludee = true;
//        RigidBody@ body = node.CreateComponent("RigidBody");
//        body.collisionLayer = 2;
//        body.collisionMask = 1;
//        CollisionShape@ shape = node.CreateComponent("CollisionShape");
//        shape.SetTriangleMesh(model, 0);
    }
}

