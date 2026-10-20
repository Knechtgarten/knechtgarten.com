-- ============================================================================
-- Pflege-Tool: Regionen (z. B. fuer Zuensler-Touren, Bewaesserung, Planung)
--
-- Jede Region hat eine PLZ-Liste (pflege_region_plz, eine PLZ gehoert genau zu
-- einer Region). Die Region eines Kunden ergibt sich automatisch aus der PLZ
-- seiner Adresse (bzw. der Objekt-Adresse). Von Hand gesetzt (region_id am
-- Kunden bzw. Objekt) geht vor. PLZ ohne Region -> Region mit ist_rest
-- («Diverse (weit entfernt)»).
-- Startdaten aus der Kontroll-Karte docs/regionen-vorschlag.html (2026-10-20).
-- ============================================================================
create table pflege_region (
  id uuid primary key default gen_random_uuid(),
  schluessel text unique,
  name text not null unique,
  farbe text not null default '#8B9097',
  reihenfolge integer not null default 0,
  ist_rest boolean not null default false,
  erstellt_am timestamptz not null default now()
);
create unique index pflege_region_ein_rest on pflege_region (ist_rest) where ist_rest;
alter table pflege_region enable row level security;
create policy pflege_region_lesen on pflege_region for select using (ist_eingeloggter_benutzer());
create policy pflege_region_buero_admin on pflege_region for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

create table pflege_region_plz (
  plz integer primary key check (plz between 1000 and 9999),
  region_id uuid not null references pflege_region(id) on delete cascade
);
alter table pflege_region_plz enable row level security;
create policy pflege_region_plz_lesen on pflege_region_plz for select using (ist_eingeloggter_benutzer());
create policy pflege_region_plz_buero_admin on pflege_region_plz for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

-- Von Hand gesetzte Region (Ausnahme zur PLZ-Regel)
alter table pflege_kunde add column region_id uuid null references pflege_region(id) on delete set null;
alter table pflege_objekt add column region_id uuid null references pflege_region(id) on delete set null;

insert into pflege_region (schluessel, name, farbe, reihenfolge, ist_rest) values
  ('thun-w',  'Thun West', '#1f77b4', 1, false),
  ('thun-o',  'Thun Ost', '#9ecae9', 2, false),
  ('steff',   'Steffisburg–Heimberg', '#ff7f0e', 3, false),
  ('ufer',    'Rechtes Thunerseeufer', '#17becf', 4, false),
  ('spiez',   'Spiez–Niedersimmental', '#2ca02c', 5, false),
  ('frutig',  'Frutigland', '#a1d99b', 6, false),
  ('ik',      'Interlaken–Bödeli', '#9467bd', 7, false),
  ('saanen',  'Obersimmental–Saanenland', '#c5b0d5', 8, false),
  ('vs',      'Wallis', '#8c564b', 9, false),
  ('heim',    'Heimenschwand (Buchholterberg–Eriz)', '#d62728', 10, false),
  ('aare',    'Aaretal (Münsingen–Belp)', '#bcbd22', 11, false),
  ('kies',    'Kiesental (Grosshöchstetten–Biglen)', '#e7d84a', 12, false),
  ('westamt', 'Westamt (Blumenstein–Wattenwil)', '#e377c2', 13, false),
  ('guerbe',  'Gürbetal (Riggisberg–Toffen)', '#f7b6d2', 14, false),
  ('bern-so', 'Bern Süd-Ost (Worb–Muri)', '#393b79', 15, false),
  ('bern-no', 'Bern Nord-Ost (Worblental–Zollikofen)', '#6b6ecf', 16, false),
  ('bern-w',  'Bern West (Köniz–Wohlen)', '#637939', 17, false),
  ('bern-n',  'Bern Nord (Fraubrunnen)', '#a6761d', 18, false),
  ('seeland', 'Seeland', '#e7969c', 19, false),
  ('solo',    'Solothurn', '#843c39', 20, false),
  ('burg',    'Burgdorf–Kirchberg', '#7b4173', 21, false),
  ('langnau', 'Langnau (Oberes Emmental)', '#fdae6b', 22, false),
  ('div',     'Diverse (weit entfernt)', '#9aa0a6', 23, true);

insert into pflege_region_plz (plz, region_id)
select p, r.id from (values
  ('thun-w',  array[3600,3604,3608,3645]),
  ('thun-o',  array[3602,3603,3624]),
  ('steff',   array[3612,3613,3627,3628,3661]),
  ('ufer',    array[3625,3626,3652,3653,3654,3655,3656,3657,3658]),
  ('spiez',   array[3646,3647,3700,3702,3703,3704,3705,3711,3752,3753,3754,3755,3756,3757,3758,3762,3763,3764,3765]),
  ('frutig',  array[3713,3714,3715,3716,3717,3718,3722,3723,3724,3725]),
  ('ik',      array[3706,3707,3800,3803,3804,3805,3806,3812,3813,3814,3852,3853]),
  ('saanen',  array[1657,3766,3770,3771,3772,3773,3775,3776,3777,3778,3780,3781,3782,3783,3784,3785,3792]),
  ('vs',      array[1868,1869,1870,1871,1872,1873,1874,1875,1890,1891,1893,1895,1896,1897,1898,1899,1902,1903,1904,1905,1906,1907,1908,1911,1912,1913,1914,1918,1920,1921,1922,1923,1925,1926,1927,1928,1929,1932,1933,1934,1936,1937,1938,1941,1942,1943,1944,1945,1946,1947,1948,1950,1955,1957,1958,1961,1962,1963,1964,1965,1966,1967,1968,1969,1971,1972,1973,1974,1975,1976,1977,1978,1981,1982,1983,1984,1985,1986,1987,1988,1991,1992,1993,1994,1996,1997,3801,3900,3901,3902,3903,3904,3905,3906,3907,3908,3910,3911,3912,3913,3914,3916,3917,3918,3919,3920,3922,3923,3924,3925,3926,3927,3928,3929,3930,3931,3932,3933,3934,3935,3937,3938,3939,3940,3942,3943,3944,3945,3946,3947,3948,3949,3951,3952,3953,3954,3955,3956,3957,3960,3961,3963,3965,3966,3967,3968,3970,3971,3972,3973,3974,3975,3976,3977,3978,3979,3982,3983,3984,3985,3986,3987,3988,3989,3991,3992,3993,3994,3995,3996,3997,3998,3999]),
  ('heim',    array[3538,3614,3615,3616,3617,3618,3619,3622,3623,3673]),
  ('aare',    array[3083,3110,3111,3112,3113,3114,3115,3116,3123,3124,3126,3503,3504,3510,3629]),
  ('kies',    array[3082,3434,3506,3507,3508,3512,3513,3531,3532,3533,3671,3672,3674]),
  ('westamt', array[3631,3632,3633,3634,3635,3636,3638,3662,3663,3664,3665]),
  ('guerbe',  array[3086,3087,3088,3089,3099,3125,3127,3128,3132,3155]),
  ('bern-so', array[3001,3005,3006,3011,3015,3067,3068,3073,3074,3075,3076,3077,3078,3084,3122]),
  ('bern-no', array[3004,3013,3014,3048,3052,3063,3065,3066,3072]),
  ('bern-w',  array[3007,3008,3010,3012,3018,3019,3020,3027,3032,3033,3034,3037,3038,3042,3043,3044,3045,3046,3047,3049,3095,3097,3098,3144,3145,3147,3172,3173,3174,3176,3177,3202,3203,3204,3205,3206]),
  ('bern-n',  array[3053,3302,3303,3305,3306,3308,3312,3313,3314,3315,3317,3322,3323,3324,3325,3326,3427]),
  ('seeland', array[1595,1786,1787,1788,1789,1793,1794,1795,1796,1797,2502,2503,2504,2505,2512,2513,2514,2532,2533,2542,2543,2552,2553,2554,2555,2556,2557,2558,2560,2562,2563,2564,2565,2572,2575,2576,2577,3035,3036,3054,3179,3207,3210,3215,3216,3225,3226,3232,3234,3235,3236,3237,3238,3250,3251,3252,3255,3256,3257,3262,3264,3266,3267,3268,3270,3271,3272,3273,3274,3280,3282,3283,3284,3285,3286,3292,3293,3294,3295,3296,3297,3298]),
  ('solo',    array[2545,3254,3307,4500,4512,4513,4514,4515,4522,4523,4528,4532,4533,4534,4542,4543,4552,4553,4558,4562,4563,4564,4565,4566,4571,4573,4574,4576,4577,4578,4579,4581,4582,4583,4584,4585,4586,4587,4588]),
  ('burg',    array[3309,3400,3412,3413,3414,3415,3419,3421,3422,3423,3424,3425,3426,3429,3432,3435,3439,3452,3472,3473,3474]),
  ('langnau', array[3433,3436,3437,3438,3534,3535,3536,3537,3543,3550,3551,3552,3553,3555,3556,3557,6197])
) v(s, plzs)
cross join lateral unnest(v.plzs) p
join pflege_region r on r.schluessel = v.s;
