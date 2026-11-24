
-- =========================================
-- 1. AUCTIONS
-- Any authenticated user can create an auction.
-- =========================================

CREATE TABLE IF NOT EXISTS public.auctions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    owner_id UUID NOT NULL
        REFERENCES auth.users(id) ON DELETE RESTRICT,

    title TEXT NOT NULL,
    description TEXT,

    starting_price NUMERIC(12,2) NOT NULL
        CHECK (starting_price > 0),

    current_price NUMERIC(12,2) NOT NULL,

    minimum_increment NUMERIC(12,2) NOT NULL
        CHECK (minimum_increment > 0),

    reserve_price NUMERIC(12,2)
        CHECK (reserve_price IS NULL OR reserve_price > 0),

    buy_now_price NUMERIC(12,2)
        CHECK (buy_now_price IS NULL OR buy_now_price > 0),

    currency CHAR(3) NOT NULL DEFAULT 'LKR',

    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,

    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'scheduled',
                'live',
                'ended',
                'cancelled'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (end_at > start_at),
    CHECK (current_price >= starting_price),
    CHECK (
        reserve_price IS NULL
        OR reserve_price >= starting_price
    ),
    CHECK (
        buy_now_price IS NULL
        OR buy_now_price >= starting_price
    )
);


-- =========================================
-- 2. AUCTION BIDS
-- =========================================

CREATE TABLE IF NOT EXISTS public.auction_bids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    auction_id UUID NOT NULL
        REFERENCES public.auctions(id) ON DELETE RESTRICT,

    bidder_id UUID NOT NULL
        REFERENCES auth.users(id) ON DELETE RESTRICT,

    bid_amount NUMERIC(12,2) NOT NULL
        CHECK (bid_amount > 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =========================================
-- 3. AUCTION WATCHLISTS
-- =========================================

CREATE TABLE IF NOT EXISTS public.auction_watchlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    auction_id UUID NOT NULL
        REFERENCES public.auctions(id) ON DELETE CASCADE,

    user_id UUID NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (auction_id, user_id)
);


-- =========================================
-- 4. AUCTION WINNERS
-- Created only by trusted backend processes.
-- =========================================

CREATE TABLE IF NOT EXISTS public.auction_winners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    auction_id UUID NOT NULL UNIQUE
        REFERENCES public.auctions(id) ON DELETE RESTRICT,

    winner_id UUID NOT NULL
        REFERENCES auth.users(id) ON DELETE RESTRICT,

    winning_bid_id UUID NOT NULL
        REFERENCES public.auction_bids(id) ON DELETE RESTRICT,

    final_price NUMERIC(12,2) NOT NULL,

    payment_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            payment_status IN (
                'pending',
                'paid',
                'failed',
                'refunded'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =========================================
-- 5. INDEXES
-- =========================================

CREATE INDEX IF NOT EXISTS idx_auctions_owner
ON public.auctions(owner_id);

CREATE INDEX IF NOT EXISTS idx_auctions_status_end
ON public.auctions(status, end_at);

CREATE INDEX IF NOT EXISTS idx_auction_bids_auction
ON public.auction_bids(auction_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_auction_bids_bidder
ON public.auction_bids(bidder_id);

CREATE INDEX IF NOT EXISTS idx_auction_watchlist_user
ON public.auction_watchlists(user_id);


-- =========================================
-- 6. ENABLE RLS
-- =========================================

ALTER TABLE public.auctions
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.auction_bids
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.auction_watchlists
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.auction_winners
ENABLE ROW LEVEL SECURITY;


-- =========================================
-- 7. AUCTION POLICIES
-- =========================================

CREATE POLICY "Read public auctions or own auctions"
ON public.auctions
FOR SELECT
TO anon, authenticated
USING (
    status IN ('scheduled', 'live', 'ended')
    OR owner_id = (SELECT auth.uid())
);


CREATE POLICY "Authenticated users create own draft auctions"
ON public.auctions
FOR INSERT
TO authenticated
WITH CHECK (
    owner_id = (SELECT auth.uid())
    AND status = 'draft'
);


-- =========================================
-- 8. BID POLICIES
-- =========================================

CREATE POLICY "Read auction bid history"
ON public.auction_bids
FOR SELECT
TO anon, authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.auctions a
        WHERE a.id = auction_bids.auction_id
          AND (
              a.status IN ('live', 'ended')
              OR a.owner_id = (SELECT auth.uid())
          )
    )
);


-- No direct INSERT, UPDATE or DELETE
-- permission for mobile users.
-- Bids will use a secure database function.


-- =========================================
-- 9. WATCHLIST POLICIES
-- =========================================

CREATE POLICY "Users view own watchlist"
ON public.auction_watchlists
FOR SELECT
TO authenticated
USING (user_id = (SELECT auth.uid()));


CREATE POLICY "Users add own watchlist"
ON public.auction_watchlists
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = (SELECT auth.uid())
);


CREATE POLICY "Users remove own watchlist"
ON public.auction_watchlists
FOR DELETE
TO authenticated
USING (
    user_id = (SELECT auth.uid())
);


-- =========================================
-- 10. DATABASE PERMISSIONS
-- =========================================

GRANT SELECT ON public.auctions
TO anon, authenticated;

GRANT INSERT (
    owner_id,
    title,
    description,
    starting_price,
    current_price,
    minimum_increment,
    reserve_price,
    buy_now_price,
    currency,
    start_at,
    end_at,
    status
)
ON public.auctions TO authenticated;

GRANT SELECT ON public.auction_bids
TO anon, authenticated;

GRANT SELECT, INSERT, DELETE
ON public.auction_watchlists
TO authenticated;

-- No mobile access to auction_winners.
-- Trusted backend access will be configured later.

-- =========================================
-- 11. SECURE BID SUBMISSION
-- =========================================

CREATE OR REPLACE FUNCTION public.place_auction_bid(
    p_auction_id UUID,
    p_bid_amount NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_auction public.auctions%ROWTYPE;
    v_bid_id UUID;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT *
    INTO v_auction
    FROM public.auctions
    WHERE id = p_auction_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Auction not found';
    END IF;

    IF v_auction.owner_id = v_user_id THEN
        RAISE EXCEPTION 'Cannot bid on your own auction';
    END IF;

    IF v_auction.status <> 'live' THEN
        RAISE EXCEPTION 'Auction is not live';
    END IF;

    IF NOW() < v_auction.start_at
       OR NOW() >= v_auction.end_at THEN
        RAISE EXCEPTION 'Auction is outside bidding time';
    END IF;

    IF p_bid_amount <
       (v_auction.current_price + v_auction.minimum_increment) THEN
        RAISE EXCEPTION 'Bid is below minimum required amount';
    END IF;

    INSERT INTO public.auction_bids (
        auction_id,
        bidder_id,
        bid_amount
    )
    VALUES (
        p_auction_id,
        v_user_id,
        p_bid_amount
    )
    RETURNING id INTO v_bid_id;

    UPDATE public.auctions
    SET current_price = p_bid_amount
    WHERE id = p_auction_id;

    RETURN v_bid_id;
END;
$$;


REVOKE ALL ON FUNCTION public.place_auction_bid(UUID, NUMERIC)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.place_auction_bid(UUID, NUMERIC)
TO authenticated;
