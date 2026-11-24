
-- =========================================
-- 1. USER PROFILES
-- =========================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id)
        ON DELETE CASCADE,

    full_name TEXT NOT NULL DEFAULT '',
    phone TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =========================================
-- 2. USER ROLES
-- =========================================

CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL REFERENCES auth.users(id)
        ON DELETE CASCADE,

    role TEXT NOT NULL CHECK (
        role IN (
            'buyer',
            'seller',
            'service_provider',
            'courier',
            'admin'
        )
    ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (user_id, role)
);


-- =========================================
-- 3. SELLER PROFILES
-- =========================================

CREATE TABLE IF NOT EXISTS public.seller_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id)
        ON DELETE CASCADE,

    business_name TEXT NOT NULL,
    phone TEXT,
    city TEXT,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'approved',
                'rejected',
                'suspended'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =========================================
-- 4. SERVICE PROVIDER PROFILES
-- =========================================

CREATE TABLE IF NOT EXISTS public.service_provider_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id)
        ON DELETE CASCADE,

    business_name TEXT NOT NULL,
    description TEXT,
    service_area TEXT,
    phone TEXT,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'approved',
                'rejected',
                'suspended'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =========================================
-- 5. CATEGORIES
-- =========================================

CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,

    category_type TEXT NOT NULL
        CHECK (
            category_type IN (
                'product',
                'service',
                'both'
            )
        ),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =========================================
-- 6. PRODUCTS
-- =========================================

CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    seller_id UUID NOT NULL REFERENCES public.seller_profiles(id)
        ON DELETE RESTRICT,

    category_id UUID REFERENCES public.categories(id)
        ON DELETE SET NULL,

    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,

    price NUMERIC(12,2) NOT NULL
        CHECK (price >= 0),

    currency CHAR(3) NOT NULL DEFAULT 'LKR',

    stock_quantity INTEGER NOT NULL DEFAULT 0
        CHECK (stock_quantity >= 0),

    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'active',
                'paused'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (seller_id, slug)
);


-- =========================================
-- 7. INDEXES
-- =========================================

CREATE INDEX IF NOT EXISTS idx_user_roles_user
ON public.user_roles(user_id);

CREATE INDEX IF NOT EXISTS idx_seller_profiles_user
ON public.seller_profiles(user_id);

CREATE INDEX IF NOT EXISTS idx_service_provider_user
ON public.service_provider_profiles(user_id);

CREATE INDEX IF NOT EXISTS idx_products_seller
ON public.products(seller_id);

CREATE INDEX IF NOT EXISTS idx_products_category
ON public.products(category_id);

CREATE INDEX IF NOT EXISTS idx_products_status
ON public.products(status);


-- =========================================
-- 8. AUTOMATIC UPDATED_AT
-- =========================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_set_updated_at
ON public.profiles;

CREATE TRIGGER profiles_set_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS products_set_updated_at
ON public.products;

CREATE TRIGGER products_set_updated_at
BEFORE UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =========================================
-- 9. CREATE PROFILE WHEN USER REGISTERS
-- =========================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN

    INSERT INTO public.profiles (
        id,
        full_name
    )
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data ->> 'full_name',
            ''
        )
    )
    ON CONFLICT (id) DO NOTHING;


    -- Every new account starts as a buyer.
    -- Additional roles require trusted approval.

    INSERT INTO public.user_roles (
        user_id,
        role
    )
    VALUES (
        NEW.id,
        'buyer'
    )
    ON CONFLICT (user_id, role) DO NOTHING;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS on_auth_user_created
ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();


-- =========================================
-- 10. ENABLE ROW LEVEL SECURITY
-- =========================================

ALTER TABLE public.profiles
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_roles
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.seller_profiles
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.service_provider_profiles
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.categories
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.products
ENABLE ROW LEVEL SECURITY;


-- =========================================
-- 11. PROFILES POLICIES
-- =========================================

DROP POLICY IF EXISTS "Users view own profile"
ON public.profiles;

CREATE POLICY "Users view own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = id);


DROP POLICY IF EXISTS "Users update own profile"
ON public.profiles;

CREATE POLICY "Users update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING ((SELECT auth.uid()) = id)
WITH CHECK ((SELECT auth.uid()) = id);


-- =========================================
-- 12. USER ROLE POLICIES
-- =========================================

DROP POLICY IF EXISTS "Users view own roles"
ON public.user_roles;

CREATE POLICY "Users view own roles"
ON public.user_roles
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = user_id);


-- =========================================
-- 13. SELLER PROFILE POLICIES
-- =========================================

DROP POLICY IF EXISTS "View approved sellers or own application"
ON public.seller_profiles;

CREATE POLICY "View approved sellers or own application"
ON public.seller_profiles
FOR SELECT
TO anon, authenticated
USING (
    status = 'approved'
    OR user_id = (SELECT auth.uid())
);


DROP POLICY IF EXISTS "Apply as seller"
ON public.seller_profiles;

CREATE POLICY "Apply as seller"
ON public.seller_profiles
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = (SELECT auth.uid())
    AND status = 'pending'
);


-- =========================================
-- 14. SERVICE PROVIDER POLICIES
-- =========================================

DROP POLICY IF EXISTS "View approved providers or own application"
ON public.service_provider_profiles;

CREATE POLICY "View approved providers or own application"
ON public.service_provider_profiles
FOR SELECT
TO anon, authenticated
USING (
    status = 'approved'
    OR user_id = (SELECT auth.uid())
);


DROP POLICY IF EXISTS "Apply as service provider"
ON public.service_provider_profiles;

CREATE POLICY "Apply as service provider"
ON public.service_provider_profiles
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = (SELECT auth.uid())
    AND status = 'pending'
);


-- =========================================
-- 15. CATEGORY POLICIES
-- =========================================

DROP POLICY IF EXISTS "Read active categories"
ON public.categories;

CREATE POLICY "Read active categories"
ON public.categories
FOR SELECT
TO anon, authenticated
USING (is_active = TRUE);


-- =========================================
-- 16. PRODUCT POLICIES
-- =========================================

DROP POLICY IF EXISTS "Read active products or own products"
ON public.products;

CREATE POLICY "Read active products or own products"
ON public.products
FOR SELECT
TO anon, authenticated
USING (
    (
        status = 'active'
        AND EXISTS (
            SELECT 1
            FROM public.seller_profiles sp
            WHERE sp.id = products.seller_id
              AND sp.status = 'approved'
        )
    )
    OR EXISTS (
        SELECT 1
        FROM public.seller_profiles sp
        WHERE sp.id = products.seller_id
          AND sp.user_id = (SELECT auth.uid())
    )
);


DROP POLICY IF EXISTS "Approved sellers create products"
ON public.products;

CREATE POLICY "Approved sellers create products"
ON public.products
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.seller_profiles sp
        WHERE sp.id = products.seller_id
          AND sp.user_id = (SELECT auth.uid())
          AND sp.status = 'approved'
    )
    AND (
        category_id IS NULL
        OR EXISTS (
            SELECT 1
            FROM public.categories c
            WHERE c.id = products.category_id
              AND c.is_active = TRUE
        )
    )
);


DROP POLICY IF EXISTS "Approved sellers update own products"
ON public.products;

CREATE POLICY "Approved sellers update own products"
ON public.products
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.seller_profiles sp
        WHERE sp.id = products.seller_id
          AND sp.user_id = (SELECT auth.uid())
          AND sp.status = 'approved'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.seller_profiles sp
        WHERE sp.id = products.seller_id
          AND sp.user_id = (SELECT auth.uid())
          AND sp.status = 'approved'
    )
    AND (
        category_id IS NULL
        OR EXISTS (
            SELECT 1
            FROM public.categories c
            WHERE c.id = products.category_id
              AND c.is_active = TRUE
        )
    )
);


-- =========================================
-- 17. DATABASE PERMISSIONS
-- =========================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT SELECT ON public.categories
TO anon, authenticated;

GRANT SELECT ON public.seller_profiles
TO anon, authenticated;

GRANT SELECT ON public.service_provider_profiles
TO anon, authenticated;

GRANT SELECT ON public.products
TO anon, authenticated;

GRANT SELECT, UPDATE (full_name, phone)
ON public.profiles
TO authenticated;

GRANT SELECT ON public.user_roles
TO authenticated;

GRANT INSERT ON public.seller_profiles
TO authenticated;

GRANT INSERT ON public.service_provider_profiles
TO authenticated;

GRANT INSERT, UPDATE ON public.products
TO authenticated;


-- =========================================
-- 18. SAMPLE CATEGORIES
-- =========================================

INSERT INTO public.categories (
    name,
    slug,
    category_type
)
VALUES
    ('Hardware & Tools', 'hardware-tools', 'product'),
    ('Home Appliances', 'home-appliances', 'product'),
    ('Books & Stationery', 'books-stationery', 'product'),
    ('Digital Products', 'digital-products', 'product'),
    ('Home Services', 'home-services', 'service')
ON CONFLICT (slug) DO NOTHING;
