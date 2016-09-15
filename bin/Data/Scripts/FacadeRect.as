class FacadeRect {
    private void calc_size()
    {
        size.x = Abs(right - left);
        size.y = Abs(top - bottom);
    }
    private float get(int idx)
    {
        switch(idx) {
        case 0:
           return left;
        case 1:
           return top;
        case 2:
           return right;
        case 3:
           return bottom;
        }
        return 0.0;
    }
    float get_opIndex(int idx)
    {
        return get(idx);
    }
    private void set(int idx, float value)
    {
        switch(idx) {
        case 0:
           set_left(value);
        case 1:
           set_top(value);
        case 2:
           set_right(value);
        case 3:
           set_bottom(value);;
        }
    }
    void set_opIndex(int idx, float value)
    {
        set(idx, value);
    }
    float left, top, right, bottom;
    float left {
        get {
            return left;
        }
        set {
            left = value;
            calc_size();
        }
    }
    float top {
        get {
            return top;
        }
        set {
            top = value;
            calc_size();
        }
    }
    float right {
        get {
            return right;
        }
        set {
            right = value;
            calc_size();
        }
    }
    float bottom {
        get {
            return bottom;
        }
        set {
            bottom = value;
            calc_size();
        }
    }
    Vector2 size;
    Array<float> ToFloatArray()
    {
        Array<float> ret = {left, top, right, bottom};
        return ret;
    }
    Array<FacadeRect> split2r(float d)
    {
        FacadeRect a1, a2;
        Array<FacadeRect> ret;
        a1.left = left;
        a1.top = top;
        a1.right = right - d;
        a1.bottom = bottom;
        a2.left = right - d;
        a2.top = top;
        a2.right = right;
        a2.bottom = bottom;
        a1.calc_size();
        a2.calc_size();
        ret.Push(a1);
        ret.Push(a2);
        return ret;
    }
    Array<FacadeRect> split2l(float d)
    {
        FacadeRect a1, a2;
        Array<FacadeRect> ret;
        a1.left = left;
        a1.top = top;
        a1.right = left + d;
        a1.bottom = bottom;
        a2.left = left + d;
        a2.top = top;
        a2.right = right;
        a2.bottom = bottom;
        a1.calc_size();
        a2.calc_size();
        ret.Push(a1);
        ret.Push(a2);
        return ret;
    }
    Array<FacadeRect> split2t(float d)
    {
        FacadeRect a1, a2;
        Array<FacadeRect> ret;
        a1.left = left;
        a1.top = top;
        a1.right = right;
        a1.bottom = top + d;
        a2.left = left;
        a2.top = top + d;
        a2.right = right;
        a2.bottom = bottom;
        a1.calc_size();
        a2.calc_size();
        ret.Push(a1);
        ret.Push(a2);
        return ret;
    }
    Array<FacadeRect> split2b(float d)
    {
        FacadeRect a1, a2;
        Array<FacadeRect> ret;
        a1.left = left;
        a1.top = top;
        a1.right = right;
        a1.bottom = bottom - d;
        a2.left = left;
        a2.top = bottom - d;
        a2.right = right;
        a2.bottom = bottom;
        a1.calc_size();
        a2.calc_size();
        ret.Push(a1);
        ret.Push(a2);
        return ret;
    }
    bool can_split(float msz, float sz)
    {
        if ((size.x > sz && size.y > msz)
                || (size.y > sz && size.x > msz))
            return true;
        return false;
    }
    bool can_vsplit(float sz)
    {
        if ((size.y > sz))
            return true;
        return false;
    }
    bool can_hsplit(float sz)
    {
        if ((size.x > sz))
            return true;
        return false;
    }
    String ToString()
    {
        String ret = "[ " + String(left) + " " + String(top) + " " + String(right) + " " + String(bottom) + " ]";
        ret += "(size: " + String(size.x) + " " + String(size.y) + " )";
        return ret;
    }
    FacadeRect(float l, float t, float r, float b)
    {
        left = l;
        top = t;
        right = r;
        bottom = b;
        size.x = Abs(r - l);
        size.y = Abs(t - b);
    }
    FacadeRect()
    {
       left = 0;
       top = 0;
       right = 0;
       bottom = 0;
       calc_size();
    }
};

