--
-- PostgreSQL database dump
--

-- Dumped from database version 12.12
-- Dumped by pg_dump version 12.12

-- Started on 2022-12-01 18:24:49

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 211 (class 1255 OID 16877)
-- Name: check_user(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_user(check_username character varying, check_user_password character varying) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF EXISTS (SELECT * FROM users WHERE username = check_username AND user_password = check_user_password)
	THEN 
		RETURN 'The data entered is correct';
	ELSE 
		RETURN 'Password or username entered incorrectly';
	END IF;
END;
$$;


ALTER FUNCTION public.check_user(check_username character varying, check_user_password character varying) OWNER TO postgres;

--
-- TOC entry 210 (class 1255 OID 16873)
-- Name: create_user(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_user(username character varying, user_password character varying, email character varying, phone_number character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	INSERT INTO users(username, user_password, email, phone_number) 
		VALUES (username, user_password, email, phone_number);
END;
$$;


ALTER FUNCTION public.create_user(username character varying, user_password character varying, email character varying, phone_number character varying) OWNER TO postgres;

--
-- TOC entry 212 (class 1255 OID 17006)
-- Name: show_songs_playlist(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_songs_playlist(_id_playlist bigint) RETURNS TABLE(id_song bigint, song_name character varying, creator_name character varying, song_link character varying, duration smallint, song_text text, id_album bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	RETURN QUERY SELECT song.id_song, song.song_name, song.creator_name, song.song_link,
	song.duration, song.song_text, song.id_album FROM song 
	INNER JOIN song_playlist_relship ON song.id_song = song_playlist_relship.id_song 
	AND _id_playlist = song_playlist_relship.id_playlist;
END;
$$;


ALTER FUNCTION public.show_songs_playlist(_id_playlist bigint) OWNER TO postgres;

--
-- TOC entry 213 (class 1255 OID 17005)
-- Name: show_user_playlist(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_user_playlist(_username character varying) RETURNS TABLE(id_playlist bigint, playlist_name character varying, music_count integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	RETURN QUERY SELECT playlist.id_playlist, playlist.playlist_name, playlist.music_count FROM playlist 
	INNER JOIN users_playlist_relship ON users_playlist_relship.id_playlist = playlist.id_playlist 
	AND users_playlist_relship.username = _username;
END;
$$;


ALTER FUNCTION public.show_user_playlist(_username character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 204 (class 1259 OID 16931)
-- Name: album; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.album (
    id_album bigint NOT NULL,
    album_name character varying(50) NOT NULL,
    creator_name character varying(50) NOT NULL
);


ALTER TABLE public.album OWNER TO postgres;

--
-- TOC entry 203 (class 1259 OID 16925)
-- Name: performer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.performer (
    performer_name character varying(50) NOT NULL,
    followers_count bigint DEFAULT 0 NOT NULL
);


ALTER TABLE public.performer OWNER TO postgres;

--
-- TOC entry 208 (class 1259 OID 16977)
-- Name: performer_users_relship; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.performer_users_relship (
    performer_name character varying(50) NOT NULL,
    username character varying(50) NOT NULL
);


ALTER TABLE public.performer_users_relship OWNER TO postgres;

--
-- TOC entry 205 (class 1259 OID 16941)
-- Name: playlist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.playlist (
    id_playlist bigint NOT NULL,
    playlist_name character varying(50) NOT NULL,
    music_count integer NOT NULL
);


ALTER TABLE public.playlist OWNER TO postgres;

--
-- TOC entry 206 (class 1259 OID 16946)
-- Name: song; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.song (
    id_song bigint NOT NULL,
    song_name character varying(50) NOT NULL,
    creator_name character varying(50) NOT NULL,
    song_link character varying(200) NOT NULL,
    duration smallint NOT NULL,
    song_text text,
    id_album bigint
);


ALTER TABLE public.song OWNER TO postgres;

--
-- TOC entry 207 (class 1259 OID 16964)
-- Name: song_playlist_relship; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.song_playlist_relship (
    id_song bigint NOT NULL,
    id_playlist bigint NOT NULL
);


ALTER TABLE public.song_playlist_relship OWNER TO postgres;

--
-- TOC entry 202 (class 1259 OID 16864)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    username character varying(50) NOT NULL,
    user_password character varying(50),
    email character varying(50),
    phone_number character varying(15)
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 16990)
-- Name: users_playlist_relship; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users_playlist_relship (
    username character varying(50) NOT NULL,
    id_playlist bigint NOT NULL
);


ALTER TABLE public.users_playlist_relship OWNER TO postgres;

--
-- TOC entry 2872 (class 0 OID 16931)
-- Dependencies: 204
-- Data for Name: album; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.album (id_album, album_name, creator_name) FROM stdin;
1	Выходи за меня	Anacondaz
\.


--
-- TOC entry 2871 (class 0 OID 16925)
-- Dependencies: 203
-- Data for Name: performer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.performer (performer_name, followers_count) FROM stdin;
Noize mc	10000000
Anacondaz	10000000
\.


--
-- TOC entry 2876 (class 0 OID 16977)
-- Dependencies: 208
-- Data for Name: performer_users_relship; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.performer_users_relship (performer_name, username) FROM stdin;
\.


--
-- TOC entry 2873 (class 0 OID 16941)
-- Dependencies: 205
-- Data for Name: playlist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.playlist (id_playlist, playlist_name, music_count) FROM stdin;
1	Liked songs	0
2	TILT	0
\.


--
-- TOC entry 2874 (class 0 OID 16946)
-- Dependencies: 206
-- Data for Name: song; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.song (id_song, song_name, creator_name, song_link, duration, song_text, id_album) FROM stdin;
1	Жвачка	Noize mc	qwerty	2	\N	\N
2	Спаси, но не сохраняй	Anacondaz	qwerty	3	\N	1
\.


--
-- TOC entry 2875 (class 0 OID 16964)
-- Dependencies: 207
-- Data for Name: song_playlist_relship; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.song_playlist_relship (id_song, id_playlist) FROM stdin;
1	1
2	1
2	2
1	2
\.


--
-- TOC entry 2870 (class 0 OID 16864)
-- Dependencies: 202
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (username, user_password, email, phone_number) FROM stdin;
Maselof	admin	mr.gindeev@mail.ru	89613960415
Noize mc	8765432	123	76543
Anacondaz	54321	6543231	543212
vasya	vasya_krutoy	vasya@mail.ru	911
\.


--
-- TOC entry 2877 (class 0 OID 16990)
-- Dependencies: 209
-- Data for Name: users_playlist_relship; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users_playlist_relship (username, id_playlist) FROM stdin;
Maselof	1
Maselof	2
Noize mc	1
\.


--
-- TOC entry 2728 (class 2606 OID 16935)
-- Name: album album_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_pkey PRIMARY KEY (id_album);


--
-- TOC entry 2726 (class 2606 OID 16930)
-- Name: performer performer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performer
    ADD CONSTRAINT performer_pkey PRIMARY KEY (performer_name);


--
-- TOC entry 2730 (class 2606 OID 16945)
-- Name: playlist playlist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.playlist
    ADD CONSTRAINT playlist_pkey PRIMARY KEY (id_playlist);


--
-- TOC entry 2732 (class 2606 OID 16953)
-- Name: song song_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_pkey PRIMARY KEY (id_song);


--
-- TOC entry 2734 (class 2606 OID 17008)
-- Name: performer_users_relship username_unique_in_relship_with_performer; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performer_users_relship
    ADD CONSTRAINT username_unique_in_relship_with_performer UNIQUE (username);


--
-- TOC entry 2720 (class 2606 OID 16870)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 2722 (class 2606 OID 16872)
-- Name: users users_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 2724 (class 2606 OID 16868)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (username);


--
-- TOC entry 2735 (class 2606 OID 16936)
-- Name: album album_creator_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_creator_name_fkey FOREIGN KEY (creator_name) REFERENCES public.performer(performer_name);


--
-- TOC entry 2740 (class 2606 OID 16980)
-- Name: performer_users_relship performer_users_relship_performer_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performer_users_relship
    ADD CONSTRAINT performer_users_relship_performer_name_fkey FOREIGN KEY (performer_name) REFERENCES public.performer(performer_name);


--
-- TOC entry 2741 (class 2606 OID 16985)
-- Name: performer_users_relship performer_users_relship_username_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performer_users_relship
    ADD CONSTRAINT performer_users_relship_username_fkey FOREIGN KEY (username) REFERENCES public.users(username);


--
-- TOC entry 2736 (class 2606 OID 16954)
-- Name: song song_creator_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_creator_name_fkey FOREIGN KEY (creator_name) REFERENCES public.performer(performer_name);


--
-- TOC entry 2737 (class 2606 OID 16959)
-- Name: song song_id_album_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_id_album_fkey FOREIGN KEY (id_album) REFERENCES public.album(id_album);


--
-- TOC entry 2739 (class 2606 OID 16972)
-- Name: song_playlist_relship song_playlist_relship_id_playlist_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song_playlist_relship
    ADD CONSTRAINT song_playlist_relship_id_playlist_fkey FOREIGN KEY (id_playlist) REFERENCES public.playlist(id_playlist);


--
-- TOC entry 2738 (class 2606 OID 16967)
-- Name: song_playlist_relship song_playlist_relship_id_song_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song_playlist_relship
    ADD CONSTRAINT song_playlist_relship_id_song_fkey FOREIGN KEY (id_song) REFERENCES public.song(id_song);


--
-- TOC entry 2743 (class 2606 OID 16998)
-- Name: users_playlist_relship users_playlist_relship_id_playlist_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_playlist_relship
    ADD CONSTRAINT users_playlist_relship_id_playlist_fkey FOREIGN KEY (id_playlist) REFERENCES public.playlist(id_playlist);


--
-- TOC entry 2742 (class 2606 OID 16993)
-- Name: users_playlist_relship users_playlist_relship_username_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_playlist_relship
    ADD CONSTRAINT users_playlist_relship_username_fkey FOREIGN KEY (username) REFERENCES public.users(username);


-- Completed on 2022-12-01 18:24:49

--
-- PostgreSQL database dump complete
--

