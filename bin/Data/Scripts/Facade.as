#include "Scripts/CreateModels.as"
#include "Scripts/FacadeRect.as"

enum facade_types {
    ITEM_FACADE,
    ITEM_FLOOR,
    ITEM_SOLID,
    ITEM_WINDOW_BLOCK,
    ITEM_WINDOWS,
    ITEM_WINDOW,
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

class DissectModel {
    String name;
    Model@ model;
    Geometry@ geometry;
    VertexBuffer@[] buffers;
    float[] vertex_data;
    uint16[] index_data;
    VectorBuffer[] vertexdata;
    Array<Vector3> verts;
    IndexBuffer@ ib;
    uint16[] index;
    DissectModel(String fn, int geonum, Matrix4 trans = Matrix4())
    {
        model = cache.GetResource("Model", fn);
        geometry = model.GetGeometry(geonum, 0);
        ib = geometry.indexBuffer;
        VectorBuffer indexdata = ib.GetData();
//        Print("numGeometries: " + String(model.numGeometries));
//        Print("indexCount: " + String(geometry.indexCount));
//        Print("indexStart: " + String(geometry.indexStart));
//        Print("vertexCount: " + String(geometry.vertexCount));
//        Print("vertexStart: " + String(geometry.vertexStart));
//        Print("numVertexBuffers: " + String(geometry.numVertexBuffers));
//        Print("primitive: " + String(geometry.primitiveType));
//        Print("primitive: " + String(TRIANGLE_LIST));
//        Print("primitive: " + String(LINE_LIST));
//        Print("primitive: " + String(POINT_LIST));
//        Print("primitive: " + String(TRIANGLE_STRIP));
//        Print("primitive: " + String(LINE_STRIP));
//        Print("primitive: " + String(TRIANGLE_FAN));
        for(int i = 0; i < geometry.numVertexBuffers; i++) {
            buffers.Push(geometry.vertexBuffers[i]);
            vertexdata.Push(geometry.vertexBuffers[i].GetData());
            uint num_verts = geometry.vertexBuffers[i].vertexCount;
            uint vertex_size = geometry.vertexBuffers[i].vertexSize;
//            Print("num_verts: " + String(num_verts));
//            Print("vertexSize: " + String(vertex_size));
/*
            if (buffers[i].HasElement(TYPE_VECTOR3, SEM_POSITION))
                Print("Has position at " +
                    String(buffers[i].GetElementOffset(TYPE_VECTOR3, SEM_POSITION)));
            else
                continue;
            if (buffers[i].HasElement(TYPE_VECTOR3, SEM_NORMAL))
                Print("Has normal at " +
                    String(buffers[i].GetElementOffset(TYPE_VECTOR3, SEM_NORMAL)));
            else
                continue;
            if (buffers[i].HasElement(TYPE_VECTOR2, SEM_TEXCOORD))
                Print("Has texture coordinate  at " +
                    String(buffers[i].GetElementOffset(TYPE_VECTOR2, SEM_TEXCOORD)));
*/
            for (int j = 0; j < num_verts; j++) {
                vertexdata[i].Seek(j * vertex_size + buffers[i].GetElementOffset(TYPE_VECTOR3, SEM_POSITION));
                verts.Push(trans * vertexdata[i].ReadVector3());
                vertexdata[i].Seek(j * vertex_size + buffers[i].GetElementOffset(TYPE_VECTOR3, SEM_NORMAL));
                verts.Push(vertexdata[i].ReadVector3());
            }
            indexdata.Seek(geometry.indexStart * ib.indexSize);
            for (int j = 0; j < geometry.indexCount; j++) {
                uint16 idx = indexdata.ReadUShort();
//                Print("Index: " + String(j) + " idx: " + String(idx));
                index.Push(idx);
            }
        }
    }
    Array<Vector3> get_vertices(Vector3 offt = Vector3())
    {
        Array<Vector3> ret;
        for(int i = 0; i < index.length; i++) {
            ret.Push(verts[index[i] * 2] + offt);
        }
        return ret;
    }
}
const float min_floor_height = 2.5;
const float min_solid_width = 2.0;
const float min_window_width = 1.8;
class Facade {
    float width;
    float height;
    float depth;
    Array<FacadeChunk> queue = {};
    Array<FacadeChunk> result = {};
    Dictionary settings;
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
    Array<FacadeRect> vsplit3(FacadeRect rect, float l, float r)
    {
        Array<FacadeRect> ret;
        Array<FacadeRect> ret1 = rect.split2t(l);
        Array<FacadeRect> ret2 = ret1[1].split2b(r);
        ret.Push(ret1[0]);
        ret.Push(ret2[0]);
        ret.Push(ret2[1]);
        return ret;
    }
    Array<FacadeChunk> vsplit3(int icenter_type, int iside_type, float d, FacadeChunk r)
    {
        Array<FacadeChunk> ret;
        Array<FacadeRect> data = vsplit3(r.rect, d, d);
        add_obj(ret, iside_type, data[0]);
        add_obj(ret, icenter_type, data[1]);
        add_obj(ret, iside_type, data[2]);
        return ret;
    }
    Array<FacadeChunk> grow(FacadeChunk c)
    {
        Array<FacadeChunk> ret;
        Array<FacadeChunk> data;
        float mfh = float(settings["min_floor_height"]);
        float wbw = float(settings["min_window_block_width"]);
        float wh = float(settings["window_height"]);
        float ww = float(settings["window_width"]);
        float wd = float(settings["window_distance"]);
        switch(c.type) {
        case ITEM_FACADE:
            if (c.rect.can_vsplit(mfh))
                ret = vsplit2(ITEM_FLOOR, ITEM_FACADE, mfh, c);
            else
                add_obj(ret, ITEM_SOLID, c.rect);
            break;
        case ITEM_FLOOR:
            if (c.rect.can_hsplit(wbw)) {
                ret = hsplit3(ITEM_WINDOW_BLOCK, ITEM_SOLID,
                    c.rect.size.x
                    - Floor(c.rect.size.x / wbw) * wbw, c);
            } else {
                add_obj(ret, ITEM_SOLID, c.rect);
            }
            break;
        case ITEM_WINDOW_BLOCK:
            if (c.rect.can_vsplit(wh)) {
                ret = vsplit3(ITEM_WINDOWS, ITEM_SOLID,
                    (c.rect.size.y - wh) / 2.0, c);
            } else {
                add_obj(ret, ITEM_SOLID, c.rect);
            }
            break;
        case  ITEM_WINDOWS:
            {
                float cl = c.rect.size.x;
                FacadeChunk dc = c;
                Array<FacadeChunk> d;
                int count = -1;
                while(cl > 0.0) {
                    if (cl < ww)
                        break;
                    d = hsplit2(ITEM_WINDOW, ITEM_WINDOWS, ww, dc);
                    add_obj(ret, ITEM_WINDOW, d[0].rect);
                    dc = d[1];
                    cl -= ww;
                    if (cl <= wd)
                        break;
                    d = hsplit2(ITEM_SOLID, ITEM_WINDOWS, wd, dc);
                    add_obj(ret, ITEM_SOLID, d[0].rect);
                    dc = d[1];
                    cl -= wd;
                    count--;
                    if (count == 0)
                        break;
                }
                if (cl > 0.0)
                    add_obj(ret, ITEM_SOLID, d[1].rect);
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
/*
    Node@ create_window(Material@ mat1, Material@ mat2)
    {
        Node@ ret = Node();
        Model@ win_model = cache.GetResource("Model", "Models/window/window1.mdl");
        StaticModel@ obj = ret.CreateComponent("StaticModel");
        obj.model = win_model;
        obj.materials[0] =  mat1;
        obj.materials[1] = mat2;
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
*/
//    Facade(float w, float h, float d, Material@ mat, Matrix4 trans = Matrix4())
    Facade(float w, float h, float d, Dictionary meta)
    {
        width = w;
        height = h;
        depth = d;
        settings = meta;
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
    }
}
class FacadeRender: ScratchModel {
    void render(float width, float height, float depth, Array<FacadeChunk> result, Array<Vector3> extra_verts = Array<Vector3>(), Matrix4 trans = Matrix4())
    {
        current_geometry = 0;
        int solids = 0;
        int windows = 0;
        Print("Render: " + String(result.length) + " results");
        for (int i = 0; i < result.length; i++) {
            Vector3 offt = Vector3(result[i].rect.left + result[i].rect.size.x / 2.0 , result[i].rect.top, 0.0);
            Matrix4 offt2 = Matrix4();
            offt2.SetTranslation(offt);
            Matrix4 ctrans = trans * offt2;
            switch(result[i].type) {
            case ITEM_SOLID:
                current_geometry = 0;
                add_quad0(result[i].rect.size.x,
                    result[i].rect.size.y, -depth, ctrans);
                add_quad1(result[i].rect.size.x,
                    result[i].rect.size.y, 0.0, ctrans);
                break;
            case ITEM_WINDOW:
//                    Node@ win = create_window(win_mat1, win_mat2);
//                    node.AddChild(win);
//                    win.position = offt + Vector3(0.0, result[i].rect.size.y / 2.0 - 0.6 /* hack!!! */, 0.0);
//                    win.rotation = Quaternion(0.0, 90, 0.0);
//                    Model@ cw = cache.GetResource("Model", "Models/window/window1.mdl");
//                    int geom_start = window_model.numGeometries;
//                    window_model.numGeometries += cw.numGeometries;
//                    for (int j = 0; j < cw.numGeometries; j++)
//                        window_model.SetGeometry(geom_start + i, 0, cw.GetGeometry(i, 0));
// Window
                    current_geometry = 1;
                    for (int j = 0; j < extra_verts.length; j++)
                        add_vertex(ctrans *(extra_verts[j] + Vector3(0.0, result[i].rect.size.y / 2.0 - 0.6 /* hack!!! */, 0.0)));

                break;
            }
        }
        Matrix4 offt3 = Matrix4();
        offt3.SetTranslation(Vector3(-width/2.0 + depth/2.0, 0.0, 0.0));
        add_quad1(depth, height, 0.0, trans * offt3);
        offt3.SetTranslation(Vector3(width/2.0 - depth/2.0, 0.0, 0.0));
        add_quad1(depth, height, 0.0, trans * offt3);
        Print("Windows: " + String(windows) + " Solids: " + String(solids));
        Print("Verices:" + String(geom[current_geometry].num_vertices()));

//        create();
//        RigidBody@ body = node.CreateComponent("RigidBody");
//        body.collisionLayer = 2;
//        body.collisionMask = 1;
//        CollisionShape@ shape = node.CreateComponent("CollisionShape");
//        shape.SetTriangleMesh(model, 0);
//        StaticModel@ win_sm = node.CreateComponent("StaticModel");
//        win_sm.model = window_model;
    }
    FacadeRender()
    {
        add_geometry();
        add_geometry();
    }
}

