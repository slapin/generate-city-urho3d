class GeomData {
    int lod = 0;
    float lod_distance = 0.0;
    Vector3[] vertex_data;
    uint16[] index_data;
    int num_vertices()
    {
        return vertex_data.length / 2;
    }
    int find_vertex(Vector3 v)
    {
        for (int i = 0; i < vertex_data.length; i+=2) {
            if (vertex_data[i].Equals(v))
                return i / 2;
        }
        return -1;
    }
    void add_vertex(Vector3 v)
    {
        uint16 idx;
        idx = num_vertices();
        vertex_data.Push(v);
        vertex_data.Push(Vector3());
        index_data.Push(idx);
    }
};

mixin class ScratchModel {
    Array<GeomData> geom;
    int lod = 0;
    float lod_distance = 0.0;
    int current_geometry = 0;
    void add_geometry()
    {
        geom.Push(GeomData());
    }
    void add_vertex(Vector3 v)
    {
        geom[current_geometry].add_vertex(v);
    }
    Model@ model = Model();
    BoundingBox bbox;
    int total_num_verts = 0;
    void create()
    {
        total_num_verts = 0;
        VertexBuffer@ vb = VertexBuffer();
        IndexBuffer@ ib = IndexBuffer();
        vb.shadowed = true;
        ib.shadowed = true;
        Array<VertexElement> elements;
        elements.Push(VertexElement(TYPE_VECTOR3, SEM_POSITION));
        elements.Push(VertexElement(TYPE_VECTOR3, SEM_NORMAL));
        Print("Creating");

        for (uint g = 0; g < geom.length; g++) {
            Vector3[]@ vertex_data = @geom[g].vertex_data;
            uint16[]@ index_data = @geom[g].index_data;
            if (geom[g].num_vertices() == 0)
                continue;
            total_num_verts += geom[g].num_vertices();
            Print("Geometry: " + String(g) + " vertices: " + String(geom[g].num_vertices()));
            for (uint i = 0; i < geom[g].index_data.length; i += 3) {
                Vector3 v1 = vertex_data[2 * index_data[i]];
                Vector3 v2 = vertex_data[2 * index_data[(i + 1)]];
                Vector3 v3 = vertex_data[2 * index_data[(i + 2)]];

                Vector3 edge1 = v1 - v2;
                Vector3 edge2 = v1 - v3;
                Vector3 normal = edge1.CrossProduct(edge2).Normalized();
                vertex_data[2 * index_data[i] + 1] = normal;
                vertex_data[2 * index_data[i + 1] + 1] = normal;
                vertex_data[2 * index_data[i + 2] + 1] = normal;
            }
        }
        vb.SetSize(total_num_verts, elements);
        VectorBuffer temp;
        for (uint g = 0; g < geom.length; g++) {
            for (uint i = 0; i < geom[g].vertex_data.length; ++i)
                temp.WriteVector3(geom[g].vertex_data[i]);
        }
        vb.SetData(temp);

        ib.SetSize(total_num_verts, false);
        temp.Clear();
        int num_geo = 0;
        for (uint g = 0; g < geom.length; g++) {
            for (uint i = 0; i < geom[g].num_vertices(); ++i)
                temp.WriteUShort(geom[g].index_data[i]);
            if (geom[g].lod == 0 && geom[g].num_vertices() > 0)
                num_geo++;
        }
        ib.SetData(temp);

        model.numGeometries = num_geo;
        int vertex_start = 0;
        int index_start = 0;
        int geom_id = 0;
        int lod_levels = 0;
        for (uint g = 0; g < geom.length; g++) {
            if (geom[g].num_vertices() == 0)
                continue;
            Geometry@ gm = Geometry();
            gm.SetVertexBuffer(0, vb);
            gm.SetIndexBuffer(ib);
            gm.SetDrawRange(TRIANGLE_LIST, index_start,
                    geom[g].num_vertices(), vertex_start,
                    geom[g].num_vertices());
            gm.lodDistance = geom[g].lod_distance;
            if (geom[g].lod > 0)
                model.numGeometryLodLevels[geom_id] = model.numGeometryLodLevels[geom_id] + 1;
            Print("lod: " + String(geom[g].lod) + " lod distance: " + String(geom[g].lod_distance));
            if (geom[g].lod > 0)
                model.SetGeometry(geom_id, geom[g].lod, gm);
            else
                model.SetGeometry(geom_id, 0, gm);
            vertex_start += geom[g].num_vertices();
            index_start += geom[g].num_vertices();
            if (g < geom.length - 1) {
                if (geom[g + 1].lod == 0)
                    geom_id++;
            }
        }
        model.boundingBox = bbox;
        Print("Model testing");
        Print("numGeometries: " + String(model.numGeometries));
        for (int i = 0; i < model.numGeometries; i++) {
            Print("geometry: " + String(i) + " lods: " + String(model.numGeometryLodLevels[i]));
        }
    }
    void add_quad0(float w, float h, float d, Matrix4 trans = Matrix4())
    {
        add_vertex(trans * Vector3(-w/2, 0, d));
        add_vertex(trans * Vector3(-w/2, h, d));
        add_vertex(trans * Vector3(w/2, 0, d));
        add_vertex(trans * Vector3(-w/2, h, d));
        add_vertex(trans * Vector3(w/2, h, d));
        add_vertex(trans * Vector3(w/2, 0, d));
    }
    void add_quad1(float w, float h, float d, Matrix4 trans = Matrix4())
    {
        add_vertex(trans * Vector3(w/2, 0, d));
        add_vertex(trans * Vector3(-w/2, h, d));
        add_vertex(trans * Vector3(-w/2, 0, d));
        add_vertex(trans * Vector3(w/2, 0, d));
        add_vertex(trans * Vector3(w/2, h, d));
        add_vertex(trans * Vector3(-w/2, h, d));
    }
    void add_quad2(float w, float h, float d)
    {
        add_vertex(Vector3(d, 0, w/2));
        add_vertex(Vector3(d, h, -w/2));
        add_vertex(Vector3(d, 0, -w/2));
        add_vertex(Vector3(d, 0, w/2));
        add_vertex(Vector3(d, h, w/2));
        add_vertex(Vector3(d, h, -w/2));
    }
    void add_quad3(float w, float h, float d)
    {
        add_vertex(Vector3(d, 0, -w/2));
        add_vertex(Vector3(d, h, -w/2));
        add_vertex(Vector3(d, 0, w/2));
        add_vertex(Vector3(d, h, -w/2));
        add_vertex(Vector3(d, h, w/2));
        add_vertex(Vector3(d, 0, w/2));
    }
    void add_quad4(float w, float h, float d)
    {
        add_vertex(Vector3(-w/2, d, -h/2));
        add_vertex(Vector3(-w/2, d, h/2));
        add_vertex(Vector3(w/2, d, -h/2));
        add_vertex(Vector3(-w/2, d, h/2));
        add_vertex(Vector3(w/2, d, h/2));
        add_vertex(Vector3(w/2, d, -h/2));
    }
    void add_quad5(float w, float h, float d)
    {
        add_vertex(Vector3(w/2, d, -h/2));
        add_vertex(Vector3(-w/2, d, h/2));
        add_vertex(Vector3(-w/2, d, -h/2));
        add_vertex(Vector3(w/2, d, -h/2));
        add_vertex(Vector3(w/2, d, h/2));
        add_vertex(Vector3(-w/2, d, h/2));
    }
}

class RoadItem : ScratchModel {
    Node@ node = Node();
    StaticModel@ object;
//    float[] vertex_data = {
//    };
//    uint16[] index_data = {
//    };
//    float width = 0.0;
//    float height = 0.0;
//    float length = 0.0;
    RoadItem(float w, float h, float l, Material@ mat)
    {
        add_geometry();
        add_quad0(w, h, -l/2);
        add_quad1(w, h, l/2);
        add_quad2(l, h, -w/2);
        add_quad3(l, h, w/2);
        add_quad4(w, l, h);
        add_quad5(w, l, 0);
        bbox = BoundingBox(Vector3(-w/2 - 0.01, -0.01, -l/2 - 0.01), Vector3(w/2 + 0.01, h + 0.01, l/2.0 + 0.01));
        create();
        object = node.CreateComponent("StaticModel");
        object.model = model;
        object.castShadows = true;
        object.occluder = true;
        object.occludee = true;
        object.material = mat;
//        RigidBody@ body = node.CreateComponent("RigidBody");
//        body.collisionLayer = 2;
//        body.collisionMask = 1;
//        CollisionShape@ shape = node.CreateComponent("CollisionShape");
//        shape.SetTriangleMesh(model, 0);

    }
}


