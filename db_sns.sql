--
-- PostgreSQL database dump
--

-- Dumped from database version 12.12
-- Dumped by pg_dump version 12.12

-- Started on 2022-12-21 08:27:10

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
-- TOC entry 2 (class 3079 OID 42111)
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- TOC entry 3020 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- TOC entry 265 (class 1255 OID 42081)
-- Name: add_album(character varying, bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE ROLE admin WITH
  NOLOGIN
  NOSUPERUSER
  INHERIT
  NOCREATEDB
  CREATEROLE
  NOREPLICATION;

CREATE ROLE listener WITH
  NOLOGIN
  NOSUPERUSER
  INHERIT
  NOCREATEDB
  NOCREATEROLE
  NOREPLICATION;

CREATE ROLE performer WITH
  NOLOGIN
  NOSUPERUSER
  INHERIT
  NOCREATEDB
  NOCREATEROLE
  NOREPLICATION;


CREATE PROCEDURE public.add_album(_album_name character varying, _user_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	IF check_injections(_album_name) OR check_injections(format('%s', _user_id)) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;
	INSERT INTO album(album_name, creator_id, cover_url) 
	VALUES(_album_name, _user_id, format('data/%s/albums/%s/img.png', _user_id, CURRVAL('album_album_id_seq')));
END;
$$;


ALTER PROCEDURE public.add_album(_album_name character varying, _user_id bigint) OWNER TO postgres;

--
-- TOC entry 270 (class 1255 OID 42087)
-- Name: add_playlist(character varying, bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_playlist(_playlist_name character varying, _user_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF check_injections(_playlist_name) OR check_injections(format('%s', _user_id)) THEN
  RAISE EXCEPTION 'Probably injections';
  END IF;
  INSERT INTO playlist(playlist_name, cover_url, creator_id)
  VALUES(_playlist_name, format('data/%s/playlists/%s/img.png', _user_id, CURRVAL('playlist_playlist_id_seq')),
		_user_id);
END;
$$;


ALTER PROCEDURE public.add_playlist(_playlist_name character varying, _user_id bigint) OWNER TO postgres;

--
-- TOC entry 287 (class 1255 OID 42302)
-- Name: add_song_in_album(bigint, bigint, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
_creator_id BIGINT;
BEGIN
	IF check_injections(FORMAT('%s', _user_id)) OR check_injections(FORMAT('%s', _album_id)) 
	OR check_injections(_song_name) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE username = SESSION_USER);
	_creator_id := (SELECT album.creator_id FROM album WHERE album.album_id = _album_id);
	IF _user_id = _creator_id OR SESSION_USER = 'postgres'
	THEN INSERT INTO song(song_name, song_url, album_id, creator_id, song_cover)
	VALUES(_song_name, format('data/%s/albums/%s/%s.mp3', _user_id, _album_id, CURRVAL('song_song_id_seq')),
		  _album_id, _user_id, format('data/%s/albums/%s/img.png', _user_id, _album_id));
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying) OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 42089)
-- Name: add_song_in_playlist(bigint, bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_song_in_playlist(_song_id bigint, _playlist_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
_creator_id BIGINT;
BEGIN
	IF check_injections(FORMAT('%s', _song_id)) 
	OR check_injections(FORMAT('%s', _playlist_id)) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE username = SESSION_USER);
	_creator_id := (SELECT playlist.creator_id FROM playlist WHERE playlist.playlist_id = _playlist_id);
	IF us_id = _creator_id OR SESSION_USER = 'postgres'
	THEN INSERT INTO song_playlist_relship(playlist_id, song_id) 
	VALUES(_playlist_id, _song_id);
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.add_song_in_playlist(_song_id bigint, _playlist_id bigint) OWNER TO postgres;

--
-- TOC entry 271 (class 1255 OID 42197)
-- Name: album_songs_count_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.album_songs_count_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$	
	BEGIN
		IF (TG_OP = 'INSERT') THEN
			UPDATE album SET songs_count = songs_count + 1 WHERE album_id = NEW.album_id;
			RETURN NEW;
		ELSE
			UPDATE album SET songs_count = songs_count - 1 WHERE album_id = OLD.album_id;
			RETURN OLD;
		END IF;
	END;
$$;


ALTER FUNCTION public.album_songs_count_trigger() OWNER TO postgres;

--
-- TOC entry 267 (class 1255 OID 42094)
-- Name: change_user_avatar(bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.change_user_avatar(_user_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
BEGIN
	IF check_injections(FORMAT('%s', _user_id)) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE users.username = SESSION_USER);
	IF _user_id = us_id OR SESSION_USER = 'postgres'
	THEN UPDATE users SET avatar_url = format('data/%s/img.png', _user_id) 
	WHERE user_id = _user_id;
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.change_user_avatar(_user_id bigint) OWNER TO postgres;

--
-- TOC entry 277 (class 1255 OID 49832)
-- Name: check_injections(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_injections(string character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
	BEGIN
		IF string SIMILAR TO '[^''"\|;]*' THEN
			RETURN FALSE;
		ELSE
			RETURN TRUE;
		END IF;
	END;
$$;


ALTER FUNCTION public.check_injections(string character varying) OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 42072)
-- Name: check_performer(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_performer(id_perf bigint) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF EXISTS (SELECT * FROM dto_performer WHERE dto_performer.performer_id = id_perf)
	THEN RETURN 'Success'; 
	ELSE RETURN 'Performers is not found';
	END IF;
END;
$$;


ALTER FUNCTION public.check_performer(id_perf bigint) OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 42073)
-- Name: check_user(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_user(check_username character varying, check_user_password character varying) RETURNS TABLE(id_user bigint, username character varying, avatar_url character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF EXISTS (SELECT * FROM users WHERE users.username = check_username AND user_password = check_user_password)
	THEN 
		RETURN QUERY SELECT users.user_id, users.username, users.avatar_url FROM users WHERE users.username = check_username;
	ELSE 
		RAISE EXCEPTION 'Password or username entered incorrectly';
	END IF;
END;
$$;


ALTER FUNCTION public.check_user(check_username character varying, check_user_password character varying) OWNER TO postgres;

--
-- TOC entry 279 (class 1255 OID 42071)
-- Name: create_performer_user(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_performer_user(username character varying, user_password character varying, email character varying, phone character varying) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF check_injections(username) OR check_injections(user_password) OR 
	check_injections(email) OR check_injections(phone) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	INSERT INTO users(username, user_password, email, phone) 
	VALUES(username, user_password, email, phone);
	INSERT INTO performer(performer_id) VALUES(CURRVAL('users_user_id_seq'));
	INSERT INTO playlist(cover_url, creator_id) 
	VALUES('data/cover_favouritePlaylist/favouritePlaylist.png', CURRVAL('users_user_id_seq'));
	EXECUTE format('CREATE USER "%s" WITH PASSWORD ''%s''', username, user_password);
	EXECUTE format('GRANT %s TO "%s"', 'performer', username);
	RETURN CURRVAL('users_user_id_seq');
END;
$$;


ALTER FUNCTION public.create_performer_user(username character varying, user_password character varying, email character varying, phone character varying) OWNER TO postgres;

--
-- TOC entry 281 (class 1255 OID 42070)
-- Name: create_user(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_user(_username character varying, user_password character varying, email character varying, phone_number character varying) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF check_injections(_username) OR check_injections(user_password) OR 
	check_injections(email) OR check_injections(phone_number) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	INSERT INTO users(username, user_password, email, phone) 
		VALUES (_username, user_password, email, phone_number);
	INSERT INTO playlist(cover_url, creator_id) 
	VALUES('data/cover_favouritePlaylist/favouritePlaylist.png', CURRVAL('users_user_id_seq'));
	EXECUTE format('CREATE USER "%s" WITH PASSWORD ''%s''', _username, user_password);
	EXECUTE format('GRANT %s TO "%s"', 'listener', _username);
	RETURN CURRVAL('users_user_id_seq');
END;
$$;


ALTER FUNCTION public.create_user(_username character varying, user_password character varying, email character varying, phone_number character varying) OWNER TO postgres;

--
-- TOC entry 266 (class 1255 OID 42084)
-- Name: delete_album(bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_album(_album_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
_creator_id BIGINT;
BEGIN
	IF check_injections(FORMAT('%s', _album_id)) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE username = SESSION_USER);
	_creator_id := (SELECT album.creator_id FROM album WHERE album.album_id = _album_id);
	IF us_id = _creator_id OR SESSION_USER = 'postgres'
	THEN DELETE FROM album WHERE album_id = _album_id;
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.delete_album(_album_id bigint) OWNER TO postgres;

--
-- TOC entry 278 (class 1255 OID 42091)
-- Name: delete_playlist(bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_playlist(_playlist_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
_creator_id BIGINT;
BEGIN
	IF check_injections(FORMAT('%s', _playlist_id)) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE username = SESSION_USER);
	_creator_id := (SELECT playlist.creator_id FROM playlist WHERE playlist.playlist_id = _playlist_id);
	IF us_id = _creator_id OR SESSION_USER = 'postgres'
	THEN DELETE FROM song_playlist_relship WHERE playlist_id = _playlist_id;
	DELETE FROM playlist WHERE playlist_id = _playlist_id;
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.delete_playlist(_playlist_id bigint) OWNER TO postgres;

--
-- TOC entry 264 (class 1255 OID 42083)
-- Name: delete_song_in_album(bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_song_in_album(_song_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
_creator_id BIGINT; 
BEGIN 
	IF check_injections(FORMAT('%s', _song_id)) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE username = SESSION_USER);
	_creator_id := (SELECT song.creator_id FROM song WHERE song.song_id = _song_id);
	IF us_id = _creator_id OR SESSION_USER = 'postgres'
	THEN DELETE FROM song_playlist_relship WHERE song_id = _song_id;
	DELETE FROM song WHERE song_id = _song_id;
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.delete_song_in_album(_song_id bigint) OWNER TO postgres;

--
-- TOC entry 286 (class 1255 OID 42090)
-- Name: delete_song_in_playlist(bigint, bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_song_in_playlist(_song_id bigint, _playlist_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
_creator_id BIGINT; 
BEGIN 
	IF check_injections(FORMAT('%s', _song_id)) 
	OR check_injections(FORMAT('%s', _playlist_id)) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE username = SESSION_USER);
	_creator_id := (SELECT song.creator_id FROM song WHERE song.song_id = _song_id);
	IF us_id = _creator_id OR SESSION_USER = 'postgres'
	THEN DELETE FROM song_playlist_relship 
	WHERE playlist_id = _playlist_id AND song_id = _song_id;
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.delete_song_in_playlist(_song_id bigint, _playlist_id bigint) OWNER TO postgres;

--
-- TOC entry 269 (class 1255 OID 42093)
-- Name: dislike_performer(bigint, bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.dislike_performer(_performer_id bigint, _user_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
BEGIN
	IF check_injections(FORMAT('%s', _performer_id)) 
	OR check_injections(FORMAT('%s', _user_id)) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE username = SESSION_USER);
	IF us_id = _user_id OR SESSION_USER = 'postgres'
	THEN DELETE FROM users_liked_performer WHERE user_id = _user_id 
	AND performer_id = _performer_id;
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.dislike_performer(_performer_id bigint, _user_id bigint) OWNER TO postgres;

--
-- TOC entry 268 (class 1255 OID 42092)
-- Name: like_performer(bigint, bigint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.like_performer(_performer_id bigint, _user_id bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE 
us_id BIGINT;
BEGIN
	IF check_injections(FORMAT('%s', _performer_id)) 
	OR check_injections(FORMAT('%s', _user_id)) THEN
    RAISE EXCEPTION 'Probably injections';
	END IF;
	us_id := (SELECT user_id FROM users WHERE username = SESSION_USER);
	IF us_id = _user_id OR SESSION_USER = 'postgres'
	THEN INSERT INTO users_liked_performer(user_id, performer_id) 
    VALUES (_user_id, _performer_id);
	ELSE RAISE EXCEPTION 'Forbidden';
	END IF;
END;
$$;


ALTER PROCEDURE public.like_performer(_performer_id bigint, _user_id bigint) OWNER TO postgres;

--
-- TOC entry 273 (class 1255 OID 42201)
-- Name: performer_followers_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.performer_followers_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$	
	BEGIN
		IF (TG_OP = 'INSERT') THEN
			UPDATE performer SET followers = followers + 1 WHERE performer_id = NEW.performer_id;
			RETURN NEW;
		ELSE
			UPDATE performer SET followers = followers - 1 WHERE performer_id = OLD.performer_id;
			RETURN OLD;
		END IF;
	END;
$$;


ALTER FUNCTION public.performer_followers_trigger() OWNER TO postgres;

--
-- TOC entry 272 (class 1255 OID 42199)
-- Name: playlist_songs_count_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.playlist_songs_count_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$	
	BEGIN
		IF (TG_OP = 'INSERT') THEN
			UPDATE playlist SET songs_count = songs_count + 1 WHERE playlist_id = NEW.playlist_id;
			RETURN NEW;
		ELSE
			UPDATE playlist SET songs_count = songs_count - 1 WHERE playlist_id = OLD.playlist_id;
			RETURN OLD;
		END IF;
	END;
$$;


ALTER FUNCTION public.playlist_songs_count_trigger() OWNER TO postgres;

--
-- TOC entry 276 (class 1255 OID 42067)
-- Name: search_albums(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_albums(word character varying) RETURNS TABLE(album_id bigint, album_name character varying, performer_id bigint, performer_name character varying, follower bigint, song_count integer, cover_url character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF check_injections(word) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;
 	IF EXISTS (SELECT * FROM album WHERE lower(album.album_name) ~ lower(word))
	THEN RETURN QUERY SELECT * FROM dto_album WHERE lower(dto_album.album_name) ~ lower(word);
	ELSE 
		RAISE EXCEPTION 'Album is not found';
	END IF;
	
END;
$$;


ALTER FUNCTION public.search_albums(word character varying) OWNER TO postgres;

--
-- TOC entry 236 (class 1255 OID 42068)
-- Name: search_performers(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_performers(word character varying) RETURNS TABLE(id_perf bigint, perf_name character varying, followers bigint, avatar_url character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	IF check_injections(word) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;
	IF EXISTS (SELECT * FROM dto_performer WHERE lower(username) ~ lower(word))
	THEN RETURN QUERY SELECT * FROM dto_performer WHERE lower(username) ~ lower(word); 
	ELSE RAISE EXCEPTION 'Performers is not found';
	END IF;
END;
$$;


ALTER FUNCTION public.search_performers(word character varying) OWNER TO postgres;

--
-- TOC entry 280 (class 1255 OID 42069)
-- Name: search_songs(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_songs(word character varying) RETURNS TABLE(id_song bigint, song_name character varying, id_album bigint, album_name character varying, performer_id bigint, performer_name character varying, song_link character varying, song_icon character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF check_injections(word) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;
	IF EXISTS (SELECT * FROM dto_song WHERE lower(dto_song.song_name) ~ lower(word))
	THEN RETURN QUERY SELECT * FROM dto_song WHERE lower(dto_song.song_name) ~ lower(word);
	ELSE RAISE EXCEPTION 'Song is not found'; 
	END IF;
END;
$$;


ALTER FUNCTION public.search_songs(word character varying) OWNER TO postgres;

--
-- TOC entry 282 (class 1255 OID 42077)
-- Name: show_album_songs(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_album_songs(id_alb bigint) RETURNS TABLE(id_song bigint, song_name character varying, id_album bigint, album_name character varying, id_performer bigint, performer_name character varying, audio_url character varying, cover_url character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	IF check_injections(format('%s', id_alb)) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;	
	IF EXISTS (SELECT * FROM album WHERE album.album_id = id_alb)
	THEN RETURN QUERY SELECT * FROM dto_song WHERE dto_song.album_id = id_alb;
	ELSE RAISE EXCEPTION 'Album not found';
	END IF;
END;
$$;


ALTER FUNCTION public.show_album_songs(id_alb bigint) OWNER TO postgres;

--
-- TOC entry 275 (class 1255 OID 42076)
-- Name: show_favourite_playlist(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_favourite_playlist(id_us bigint) RETURNS TABLE(id_playlist bigint, playlist_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF check_injections(format('%s', id_us)) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;	
	RETURN QUERY SELECT playlist.playlist_id, playlist.playlist_name FROM playlist 
	LEFT JOIN users_playlist_relship ON users_playlist_relship.playlist_id = playlist.playlist_id 
	AND users_playlist_relship.user_id = id_us;
END;
$$;


ALTER FUNCTION public.show_favourite_playlist(id_us bigint) OWNER TO postgres;

--
-- TOC entry 283 (class 1255 OID 42075)
-- Name: show_liked_performers(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_liked_performers(id_us bigint) RETURNS TABLE(id_performer bigint, performer_name character varying, followers bigint, avatar_url character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	IF check_injections(format('%s', id_us)) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;	
	RETURN QUERY SELECT dto_performer.performer_id, dto_performer.username,
	dto_performer.followers, dto_performer.avatar_url FROM dto_performer 
	INNER JOIN users_liked_performer ON users_liked_performer.performer_id = dto_performer.performer_id
	AND users_liked_performer.user_id = id_us INNER JOIN users ON users.user_id = dto_performer.performer_id;
END;
$$;


ALTER FUNCTION public.show_liked_performers(id_us bigint) OWNER TO postgres;

--
-- TOC entry 288 (class 1255 OID 49866)
-- Name: show_performer_albums(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_performer_albums(id_perf bigint) RETURNS TABLE(id_album bigint, album_name character varying, creator_id bigint, songs_count integer, cover_url character varying, performer_name character varying, followers bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	IF check_injections(format('%s', id_perf)) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;	
	RETURN QUERY SELECT dto_album.album_id, dto_album.album_name, dto_album.creator_id, 
	dto_album.songs_count, dto_album.cover_url, dto_album.username, 
	dto_album.followers FROM dto_album WHERE id_perf = dto_album.creator_id;
END;
$$;


ALTER FUNCTION public.show_performer_albums(id_perf bigint) OWNER TO postgres;

--
-- TOC entry 284 (class 1255 OID 42078)
-- Name: show_playlist_songs(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_playlist_songs(id_pl bigint) RETURNS TABLE(id_song bigint, song_name character varying, id_album bigint, album_name character varying, id_performer bigint, performer_name character varying, audio_url character varying, cover_url character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF check_injections(format('%s', id_pl)) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;	
	IF EXISTS (SELECT * FROM playlist WHERE playlist.playlist_id = id_pl)
	THEN RETURN QUERY SELECT dto_song.song_id, dto_song.song_name, dto_song.album_id, dto_song.album_name, 
	dto_song.creator_id, dto_song.username, dto_song.song_url, dto_song.song_cover FROM dto_song 
	INNER JOIN song_playlist_relship ON song_playlist_relship.song_id = dto_song.song_id
	AND song_playlist_relship.playlist_id = id_pl;
	ELSE RAISE EXCEPTION 'Playlist not found';
	END IF;
END;
$$;


ALTER FUNCTION public.show_playlist_songs(id_pl bigint) OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 42079)
-- Name: show_user_playlists(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_user_playlists(id_us bigint) RETURNS TABLE(id_playlist bigint, playlist_name character varying, creator_id bigint, music_count integer, cover_url character varying, creator_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	IF check_injections(format('%s', id_us)) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;	
	RETURN QUERY SELECT * FROM dto_playlist WHERE dto_playlist.creator_id = id_us;
END;
$$;


ALTER FUNCTION public.show_user_playlists(id_us bigint) OWNER TO postgres;

--
-- TOC entry 206 (class 1259 OID 41982)
-- Name: album_album_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.album_album_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.album_album_id_seq OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 207 (class 1259 OID 41984)
-- Name: album; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.album (
    album_id bigint DEFAULT nextval('public.album_album_id_seq'::regclass) NOT NULL,
    album_name character varying(50) NOT NULL,
    creator_id bigint,
    songs_count integer DEFAULT 0 NOT NULL,
    cover_url character varying(100) NOT NULL
);


ALTER TABLE public.album OWNER TO postgres;

--
-- TOC entry 205 (class 1259 OID 41971)
-- Name: performer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.performer (
    performer_id bigint NOT NULL,
    followers bigint DEFAULT 0
);


ALTER TABLE public.performer OWNER TO postgres;

--
-- TOC entry 203 (class 1259 OID 41960)
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_user_id_seq OWNER TO postgres;

--
-- TOC entry 204 (class 1259 OID 41962)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id bigint DEFAULT nextval('public.users_user_id_seq'::regclass) NOT NULL,
    username character varying(50) NOT NULL,
    user_password character varying(97) NOT NULL,
    email character varying(50) NOT NULL,
    phone character varying(50) NOT NULL,
    avatar_url character varying(100) DEFAULT 'data/unknown/unknown.png'::character varying NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 42286)
-- Name: dto_album; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.dto_album AS
 SELECT album.album_id,
    album.album_name,
    album.creator_id,
    users.username,
    performer.followers,
    album.songs_count,
    album.cover_url
   FROM public.users,
    public.performer,
    public.album
  WHERE ((album.creator_id = users.user_id) AND (users.user_id = performer.performer_id));


ALTER TABLE public.dto_album OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 42290)
-- Name: dto_performer; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.dto_performer AS
 SELECT performer.performer_id,
    users.username,
    performer.followers,
    users.avatar_url
   FROM public.performer,
    public.users
  WHERE (performer.performer_id = users.user_id);


ALTER TABLE public.dto_performer OWNER TO postgres;

--
-- TOC entry 210 (class 1259 OID 42014)
-- Name: playlist_playlist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.playlist_playlist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.playlist_playlist_id_seq OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 42016)
-- Name: playlist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.playlist (
    playlist_id bigint DEFAULT nextval('public.playlist_playlist_id_seq'::regclass) NOT NULL,
    playlist_name character varying(50) DEFAULT 'Favourite Songs'::character varying NOT NULL,
    cover_url character varying(100) NOT NULL,
    creator_id bigint,
    songs_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.playlist OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 42294)
-- Name: dto_playlist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.dto_playlist AS
 SELECT playlist.playlist_id,
    playlist.playlist_name,
    playlist.creator_id,
    playlist.songs_count,
    playlist.cover_url,
    users.username
   FROM public.playlist,
    public.users
  WHERE (playlist.creator_id = users.user_id);


ALTER TABLE public.dto_playlist OWNER TO postgres;

--
-- TOC entry 208 (class 1259 OID 41996)
-- Name: song_song_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.song_song_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.song_song_id_seq OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 41998)
-- Name: song; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.song (
    song_id bigint DEFAULT nextval('public.song_song_id_seq'::regclass) NOT NULL,
    song_name character varying(100) NOT NULL,
    song_url character varying(100) NOT NULL,
    album_id bigint,
    creator_id bigint,
    song_cover character varying(100) NOT NULL
);


ALTER TABLE public.song OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 42298)
-- Name: dto_song; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.dto_song AS
 SELECT song.song_id,
    song.song_name,
    song.album_id,
    album.album_name,
    song.creator_id,
    users.username,
    song.song_url,
    song.song_cover
   FROM public.song,
    public.album,
    public.users
  WHERE ((song.creator_id = users.user_id) AND (album.album_id = song.album_id));


ALTER TABLE public.dto_song OWNER TO postgres;

--
-- TOC entry 212 (class 1259 OID 42028)
-- Name: song_playlist_relship; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.song_playlist_relship (
    song_id bigint NOT NULL,
    playlist_id bigint NOT NULL
);


ALTER TABLE public.song_playlist_relship OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 42041)
-- Name: users_liked_performer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users_liked_performer (
    performer_id bigint NOT NULL,
    user_id bigint NOT NULL
);


ALTER TABLE public.users_liked_performer OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 42054)
-- Name: users_playlist_relship; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users_playlist_relship (
    playlist_id bigint NOT NULL,
    user_id bigint NOT NULL
);


ALTER TABLE public.users_playlist_relship OWNER TO postgres;

--
-- TOC entry 3007 (class 0 OID 41984)
-- Dependencies: 207
-- Data for Name: album; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.album (album_id, album_name, creator_id, songs_count, cover_url) FROM stdin;
\.


--
-- TOC entry 3005 (class 0 OID 41971)
-- Dependencies: 205
-- Data for Name: performer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.performer (performer_id, followers) FROM stdin;
4	0
5	0
6	0
7	0
8	0
9	0
10	0
11	0
12	0
13	0
14	0
15	0
16	0
17	0
18	0
19	0
20	0
21	0
22	0
23	0
24	0
25	0
26	0
27	0
28	0
29	0
30	0
31	0
32	0
33	0
34	0
35	0
36	0
37	0
38	0
39	0
40	0
41	0
42	0
43	0
44	0
45	0
46	0
47	0
48	0
49	0
50	0
51	0
52	0
53	0
54	0
55	0
56	0
57	0
58	0
59	0
60	0
61	0
62	0
63	0
64	0
65	0
66	0
67	0
68	0
69	0
70	0
71	0
72	0
73	0
74	0
75	0
76	0
77	0
78	0
79	0
80	0
81	0
82	0
83	0
84	0
85	0
86	0
87	0
88	0
89	0
90	0
91	0
92	0
93	0
94	0
95	0
96	0
97	0
98	0
99	0
100	0
101	0
102	0
103	0
104	0
105	0
106	0
107	0
108	0
109	0
110	0
111	0
112	0
113	0
114	0
115	0
116	0
117	0
118	0
119	0
120	0
121	0
122	0
123	0
124	0
125	0
126	0
127	0
128	0
129	0
130	0
131	0
132	0
133	0
134	0
135	0
136	0
137	0
138	0
139	0
140	0
141	0
142	0
143	0
144	0
145	0
146	0
147	0
148	0
149	0
150	0
151	0
152	0
153	0
154	0
155	0
156	0
157	0
158	0
159	0
160	0
161	0
162	0
163	0
164	0
165	0
166	0
167	0
168	0
169	0
170	0
171	0
172	0
173	0
174	0
175	0
176	0
177	0
178	0
179	0
180	0
181	0
182	0
183	0
184	0
185	0
186	0
187	0
188	0
189	0
190	0
191	0
192	0
193	0
194	0
195	0
196	0
197	0
198	0
199	0
200	0
201	0
202	0
203	0
204	0
205	0
206	0
207	0
208	0
209	0
210	0
211	0
212	0
213	0
214	0
215	0
216	0
217	0
218	0
219	0
220	0
221	0
222	0
223	0
224	0
225	0
226	0
227	0
228	0
229	0
230	0
231	0
232	0
233	0
234	0
235	0
236	0
237	0
238	0
239	0
240	0
241	0
242	0
243	0
244	0
245	0
246	0
247	0
248	0
249	0
250	0
251	0
252	0
253	0
254	0
255	0
256	0
257	0
258	0
259	0
260	0
261	0
262	0
263	0
264	0
265	0
266	0
267	0
268	0
269	0
270	0
271	0
272	0
273	0
274	0
275	0
276	0
277	0
278	0
279	0
280	0
281	0
282	0
283	0
284	0
285	0
286	0
287	0
288	0
289	0
290	0
291	0
292	0
293	0
294	0
295	0
296	0
297	0
298	0
299	0
300	0
301	0
302	0
303	0
304	0
305	0
306	0
307	0
308	0
309	0
310	0
311	0
312	0
313	0
314	0
315	0
316	0
317	0
318	0
319	0
320	0
321	0
322	0
323	0
324	0
325	0
326	0
327	0
328	0
329	0
330	0
331	0
332	0
333	0
334	0
335	0
336	0
337	0
338	0
339	0
340	0
341	0
342	0
343	0
344	0
345	0
346	0
347	0
348	0
349	0
350	0
351	0
352	0
353	0
354	0
355	0
356	0
357	0
358	0
359	0
360	0
361	0
362	0
363	0
364	0
365	0
366	0
367	0
368	0
369	0
370	0
371	0
372	0
373	0
374	0
375	0
376	0
377	0
378	0
379	0
380	0
381	0
382	0
383	0
384	0
385	0
386	0
387	0
388	0
389	0
390	0
391	0
392	0
393	0
394	0
395	0
396	0
397	0
398	0
399	0
400	0
401	0
402	0
403	0
404	0
405	0
406	0
407	0
408	0
409	0
410	0
411	0
412	0
413	0
414	0
415	0
416	0
417	0
418	0
419	0
420	0
421	0
422	0
423	0
424	0
425	0
426	0
427	0
428	0
429	0
430	0
431	0
432	0
433	0
434	0
435	0
436	0
437	0
438	0
439	0
440	0
441	0
442	0
443	0
444	0
445	0
446	0
447	0
448	0
449	0
450	0
451	0
452	0
453	0
454	0
455	0
456	0
457	0
458	0
459	0
460	0
461	0
462	0
463	0
464	0
465	0
466	0
467	0
468	0
469	0
470	0
471	0
472	0
473	0
474	0
475	0
476	0
477	0
478	0
479	0
480	0
481	0
482	0
483	0
484	0
485	0
486	0
487	0
488	0
489	0
490	0
491	0
492	0
493	0
494	0
495	0
496	0
497	0
498	0
499	0
500	0
501	0
502	0
503	0
504	0
505	0
506	0
507	0
508	0
509	0
510	0
511	0
512	0
513	0
514	0
515	0
516	0
517	0
518	0
519	0
520	0
521	0
522	0
523	0
524	0
525	0
526	0
527	0
528	0
529	0
530	0
531	0
532	0
533	0
534	0
535	0
536	0
537	0
538	0
539	0
540	0
541	0
542	0
543	0
544	0
545	0
546	0
547	0
548	0
549	0
550	0
551	0
552	0
553	0
554	0
555	0
556	0
557	0
558	0
559	0
560	0
561	0
562	0
563	0
564	0
565	0
566	0
567	0
568	0
569	0
570	0
571	0
572	0
573	0
574	0
575	0
576	0
577	0
578	0
579	0
580	0
581	0
582	0
583	0
584	0
585	0
586	0
587	0
588	0
589	0
590	0
591	0
592	0
593	0
594	0
595	0
596	0
597	0
598	0
599	0
600	0
601	0
602	0
603	0
604	0
605	0
606	0
607	0
608	0
609	0
610	0
611	0
612	0
613	0
614	0
615	0
616	0
617	0
618	0
619	0
620	0
621	0
622	0
623	0
624	0
625	0
626	0
627	0
628	0
629	0
630	0
631	0
632	0
633	0
634	0
635	0
636	0
637	0
638	0
639	0
640	0
641	0
642	0
643	0
644	0
645	0
646	0
647	0
648	0
649	0
650	0
651	0
652	0
653	0
654	0
655	0
656	0
657	0
658	0
659	0
660	0
661	0
662	0
663	0
664	0
665	0
666	0
667	0
668	0
669	0
670	0
671	0
672	0
673	0
674	0
675	0
676	0
677	0
678	0
679	0
680	0
681	0
682	0
683	0
684	0
685	0
686	0
687	0
688	0
689	0
690	0
691	0
692	0
693	0
694	0
695	0
696	0
697	0
698	0
699	0
700	0
701	0
702	0
703	0
704	0
705	0
706	0
707	0
708	0
709	0
710	0
711	0
712	0
713	0
714	0
715	0
716	0
717	0
718	0
719	0
720	0
721	0
722	0
723	0
\.


--
-- TOC entry 3011 (class 0 OID 42016)
-- Dependencies: 211
-- Data for Name: playlist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.playlist (playlist_id, playlist_name, cover_url, creator_id, songs_count) FROM stdin;
13	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	9	0
14	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	10	0
15	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	11	0
16	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	12	0
17	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	13	0
18	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	14	0
19	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	15	0
20	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	16	0
21	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	17	0
22	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	18	0
23	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	19	0
24	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	20	0
25	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	21	0
26	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	22	0
27	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	23	0
28	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	24	0
29	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	25	0
30	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	26	0
31	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	27	0
32	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	28	0
33	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	29	0
34	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	30	0
35	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	31	0
36	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	32	0
37	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	33	0
38	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	34	0
39	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	35	0
40	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	36	0
41	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	37	0
42	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	38	0
43	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	39	0
44	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	40	0
45	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	41	0
46	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	42	0
47	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	43	0
48	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	44	0
49	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	45	0
8	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	4	0
9	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	5	0
10	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	6	0
11	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	7	0
12	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	8	0
50	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	46	0
51	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	47	0
52	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	48	0
53	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	49	0
54	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	50	0
55	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	51	0
56	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	52	0
57	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	53	0
58	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	54	0
59	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	55	0
60	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	56	0
61	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	57	0
62	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	58	0
63	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	59	0
64	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	60	0
65	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	61	0
66	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	62	0
67	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	63	0
68	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	64	0
69	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	65	0
70	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	66	0
71	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	67	0
72	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	68	0
73	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	69	0
74	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	70	0
75	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	71	0
76	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	72	0
77	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	73	0
78	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	74	0
79	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	75	0
80	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	76	0
81	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	77	0
82	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	78	0
83	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	79	0
84	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	80	0
85	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	81	0
86	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	82	0
87	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	83	0
88	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	84	0
89	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	85	0
90	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	86	0
91	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	87	0
92	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	88	0
93	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	89	0
94	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	90	0
95	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	91	0
96	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	92	0
97	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	93	0
98	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	94	0
99	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	95	0
100	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	96	0
101	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	97	0
102	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	98	0
103	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	99	0
104	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	100	0
105	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	101	0
106	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	102	0
107	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	103	0
108	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	104	0
109	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	105	0
110	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	106	0
111	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	107	0
112	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	108	0
113	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	109	0
114	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	110	0
115	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	111	0
116	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	112	0
117	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	113	0
118	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	114	0
119	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	115	0
120	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	116	0
121	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	117	0
122	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	118	0
123	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	119	0
124	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	120	0
125	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	121	0
126	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	122	0
127	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	123	0
128	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	124	0
129	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	125	0
130	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	126	0
131	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	127	0
132	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	128	0
133	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	129	0
134	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	130	0
135	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	131	0
136	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	132	0
137	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	133	0
138	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	134	0
139	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	135	0
140	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	136	0
141	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	137	0
142	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	138	0
143	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	139	0
144	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	140	0
145	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	141	0
146	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	142	0
147	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	143	0
148	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	144	0
149	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	145	0
150	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	146	0
151	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	147	0
152	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	148	0
153	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	149	0
154	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	150	0
155	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	151	0
156	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	152	0
157	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	153	0
158	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	154	0
159	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	155	0
160	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	156	0
161	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	157	0
162	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	158	0
163	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	159	0
164	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	160	0
165	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	161	0
166	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	162	0
167	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	163	0
168	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	164	0
169	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	165	0
170	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	166	0
171	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	167	0
172	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	168	0
173	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	169	0
174	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	170	0
175	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	171	0
176	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	172	0
177	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	173	0
178	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	174	0
179	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	175	0
180	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	176	0
181	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	177	0
182	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	178	0
183	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	179	0
184	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	180	0
185	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	181	0
186	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	182	0
187	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	183	0
188	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	184	0
189	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	185	0
190	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	186	0
191	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	187	0
192	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	188	0
193	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	189	0
194	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	190	0
195	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	191	0
196	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	192	0
197	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	193	0
198	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	194	0
199	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	195	0
200	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	196	0
201	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	197	0
202	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	198	0
203	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	199	0
204	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	200	0
205	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	201	0
206	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	202	0
207	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	203	0
208	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	204	0
209	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	205	0
210	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	206	0
211	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	207	0
212	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	208	0
213	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	209	0
214	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	210	0
215	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	211	0
216	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	212	0
217	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	213	0
218	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	214	0
219	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	215	0
220	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	216	0
221	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	217	0
222	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	218	0
223	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	219	0
224	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	220	0
225	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	221	0
226	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	222	0
227	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	223	0
228	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	224	0
229	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	225	0
230	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	226	0
231	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	227	0
232	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	228	0
233	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	229	0
234	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	230	0
235	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	231	0
236	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	232	0
237	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	233	0
238	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	234	0
239	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	235	0
240	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	236	0
241	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	237	0
242	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	238	0
243	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	239	0
244	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	240	0
245	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	241	0
246	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	242	0
247	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	243	0
248	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	244	0
249	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	245	0
250	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	246	0
251	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	247	0
252	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	248	0
253	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	249	0
254	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	250	0
255	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	251	0
256	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	252	0
257	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	253	0
258	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	254	0
259	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	255	0
260	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	256	0
261	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	257	0
262	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	258	0
263	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	259	0
264	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	260	0
265	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	261	0
266	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	262	0
267	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	263	0
268	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	264	0
269	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	265	0
270	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	266	0
271	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	267	0
272	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	268	0
273	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	269	0
274	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	270	0
275	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	271	0
276	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	272	0
277	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	273	0
278	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	274	0
279	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	275	0
280	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	276	0
281	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	277	0
282	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	278	0
283	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	279	0
284	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	280	0
285	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	281	0
286	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	282	0
287	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	283	0
288	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	284	0
289	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	285	0
290	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	286	0
291	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	287	0
292	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	288	0
293	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	289	0
294	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	290	0
295	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	291	0
296	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	292	0
297	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	293	0
298	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	294	0
299	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	295	0
300	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	296	0
301	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	297	0
302	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	298	0
303	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	299	0
304	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	300	0
305	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	301	0
306	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	302	0
307	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	303	0
308	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	304	0
309	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	305	0
310	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	306	0
311	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	307	0
312	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	308	0
313	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	309	0
314	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	310	0
315	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	311	0
316	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	312	0
317	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	313	0
318	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	314	0
319	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	315	0
320	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	316	0
321	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	317	0
322	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	318	0
323	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	319	0
324	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	320	0
325	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	321	0
326	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	322	0
327	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	323	0
328	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	324	0
329	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	325	0
330	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	326	0
331	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	327	0
332	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	328	0
333	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	329	0
334	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	330	0
335	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	331	0
336	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	332	0
337	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	333	0
338	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	334	0
339	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	335	0
340	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	336	0
341	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	337	0
342	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	338	0
343	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	339	0
344	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	340	0
345	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	341	0
346	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	342	0
347	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	343	0
348	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	344	0
349	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	345	0
350	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	346	0
351	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	347	0
352	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	348	0
353	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	349	0
354	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	350	0
355	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	351	0
356	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	352	0
357	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	353	0
358	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	354	0
359	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	355	0
360	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	356	0
361	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	357	0
362	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	358	0
363	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	359	0
364	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	360	0
365	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	361	0
366	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	362	0
367	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	363	0
368	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	364	0
369	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	365	0
370	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	366	0
371	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	367	0
372	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	368	0
373	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	369	0
374	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	370	0
375	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	371	0
376	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	372	0
377	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	373	0
378	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	374	0
379	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	375	0
380	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	376	0
381	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	377	0
382	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	378	0
383	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	379	0
384	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	380	0
385	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	381	0
386	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	382	0
387	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	383	0
388	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	384	0
389	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	385	0
390	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	386	0
391	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	387	0
392	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	388	0
393	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	389	0
394	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	390	0
395	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	391	0
396	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	392	0
397	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	393	0
398	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	394	0
399	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	395	0
400	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	396	0
401	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	397	0
402	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	398	0
403	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	399	0
404	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	400	0
405	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	401	0
406	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	402	0
407	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	403	0
408	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	404	0
409	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	405	0
410	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	406	0
411	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	407	0
412	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	408	0
413	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	409	0
414	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	410	0
415	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	411	0
416	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	412	0
417	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	413	0
418	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	414	0
419	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	415	0
420	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	416	0
421	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	417	0
422	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	418	0
423	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	419	0
424	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	420	0
425	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	421	0
426	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	422	0
427	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	423	0
428	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	424	0
429	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	425	0
430	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	426	0
431	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	427	0
432	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	428	0
433	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	429	0
434	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	430	0
435	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	431	0
436	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	432	0
437	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	433	0
438	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	434	0
439	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	435	0
440	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	436	0
441	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	437	0
442	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	438	0
443	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	439	0
444	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	440	0
445	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	441	0
446	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	442	0
447	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	443	0
448	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	444	0
449	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	445	0
450	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	446	0
451	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	447	0
452	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	448	0
453	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	449	0
454	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	450	0
455	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	451	0
456	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	452	0
457	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	453	0
458	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	454	0
459	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	455	0
460	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	456	0
461	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	457	0
462	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	458	0
463	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	459	0
464	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	460	0
465	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	461	0
466	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	462	0
467	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	463	0
468	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	464	0
469	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	465	0
470	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	466	0
471	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	467	0
472	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	468	0
473	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	469	0
474	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	470	0
475	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	471	0
476	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	472	0
477	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	473	0
478	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	474	0
479	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	475	0
480	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	476	0
481	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	477	0
482	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	478	0
483	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	479	0
484	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	480	0
485	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	481	0
486	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	482	0
487	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	483	0
488	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	484	0
489	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	485	0
490	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	486	0
491	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	487	0
492	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	488	0
493	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	489	0
494	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	490	0
495	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	491	0
496	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	492	0
497	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	493	0
498	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	494	0
499	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	495	0
500	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	496	0
501	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	497	0
502	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	498	0
503	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	499	0
504	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	500	0
505	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	501	0
506	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	502	0
507	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	503	0
508	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	504	0
509	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	505	0
510	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	506	0
511	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	507	0
512	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	508	0
513	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	509	0
514	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	510	0
515	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	511	0
516	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	512	0
517	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	513	0
518	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	514	0
519	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	515	0
520	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	516	0
521	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	517	0
522	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	518	0
523	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	519	0
524	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	520	0
525	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	521	0
526	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	522	0
527	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	523	0
528	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	524	0
529	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	525	0
530	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	526	0
531	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	527	0
532	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	528	0
533	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	529	0
534	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	530	0
535	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	531	0
536	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	532	0
537	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	533	0
538	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	534	0
539	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	535	0
540	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	536	0
541	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	537	0
542	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	538	0
543	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	539	0
544	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	540	0
545	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	541	0
546	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	542	0
547	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	543	0
548	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	544	0
549	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	545	0
550	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	546	0
551	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	547	0
552	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	548	0
553	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	549	0
554	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	550	0
555	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	551	0
556	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	552	0
557	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	553	0
558	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	554	0
559	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	555	0
560	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	556	0
561	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	557	0
562	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	558	0
563	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	559	0
564	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	560	0
565	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	561	0
566	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	562	0
567	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	563	0
568	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	564	0
569	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	565	0
570	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	566	0
571	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	567	0
572	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	568	0
573	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	569	0
574	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	570	0
575	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	571	0
576	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	572	0
577	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	573	0
578	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	574	0
579	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	575	0
580	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	576	0
581	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	577	0
582	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	578	0
583	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	579	0
584	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	580	0
585	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	581	0
586	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	582	0
587	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	583	0
588	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	584	0
589	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	585	0
590	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	586	0
591	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	587	0
592	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	588	0
593	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	589	0
594	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	590	0
595	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	591	0
596	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	592	0
597	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	593	0
598	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	594	0
599	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	595	0
600	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	596	0
601	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	597	0
602	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	598	0
603	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	599	0
604	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	600	0
605	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	601	0
606	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	602	0
607	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	603	0
608	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	604	0
609	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	605	0
610	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	606	0
611	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	607	0
612	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	608	0
613	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	609	0
614	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	610	0
615	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	611	0
616	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	612	0
617	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	613	0
618	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	614	0
619	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	615	0
620	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	616	0
621	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	617	0
622	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	618	0
623	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	619	0
624	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	620	0
625	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	621	0
626	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	622	0
627	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	623	0
628	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	624	0
629	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	625	0
630	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	626	0
631	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	627	0
632	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	628	0
633	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	629	0
634	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	630	0
635	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	631	0
636	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	632	0
637	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	633	0
638	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	634	0
639	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	635	0
640	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	636	0
641	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	637	0
642	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	638	0
643	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	639	0
644	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	640	0
645	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	641	0
646	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	642	0
647	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	643	0
648	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	644	0
649	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	645	0
650	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	646	0
651	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	647	0
652	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	648	0
653	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	649	0
654	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	650	0
655	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	651	0
656	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	652	0
657	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	653	0
658	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	654	0
659	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	655	0
660	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	656	0
661	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	657	0
662	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	658	0
663	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	659	0
664	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	660	0
665	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	661	0
666	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	662	0
667	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	663	0
668	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	664	0
669	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	665	0
670	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	666	0
671	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	667	0
672	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	668	0
673	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	669	0
674	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	670	0
675	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	671	0
676	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	672	0
677	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	673	0
678	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	674	0
679	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	675	0
680	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	676	0
681	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	677	0
682	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	678	0
683	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	679	0
684	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	680	0
685	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	681	0
686	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	682	0
687	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	683	0
688	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	684	0
689	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	685	0
690	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	686	0
691	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	687	0
692	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	688	0
693	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	689	0
694	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	690	0
695	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	691	0
696	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	692	0
697	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	693	0
698	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	694	0
699	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	695	0
700	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	696	0
701	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	697	0
702	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	698	0
703	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	699	0
704	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	700	0
705	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	701	0
706	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	702	0
707	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	703	0
708	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	704	0
709	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	705	0
710	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	706	0
711	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	707	0
712	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	708	0
713	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	709	0
714	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	710	0
715	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	711	0
716	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	712	0
717	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	713	0
718	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	714	0
719	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	715	0
720	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	716	0
721	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	717	0
722	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	718	0
723	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	719	0
724	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	720	0
725	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	721	0
726	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	722	0
727	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	723	0
\.


--
-- TOC entry 3009 (class 0 OID 41998)
-- Dependencies: 209
-- Data for Name: song; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.song (song_id, song_name, song_url, album_id, creator_id, song_cover) FROM stdin;
\.


--
-- TOC entry 3012 (class 0 OID 42028)
-- Dependencies: 212
-- Data for Name: song_playlist_relship; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.song_playlist_relship (song_id, playlist_id) FROM stdin;
\.


--
-- TOC entry 3004 (class 0 OID 41962)
-- Dependencies: 204
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, username, user_password, email, phone, avatar_url) FROM stdin;
33	city_human_alfa	571f996965fd58cc260584240abb1f29205334c71280c7e056b14dd6d2bf3355	city_human_alfa@mail.ru	371784748972	data/unknown/unknown.png
34	city_human_delta	1169436d3042cc1c5118655456983f9a8351e694c0bc2da02d15fb68e0dea763	city_human_delta@mail.ru	826858116551	data/unknown/unknown.png
35	city_human_gamma	d738b786f6722061bb177bd92bfcf2f81961c0ab5a3c0ee4103cdac36e9981ec	city_human_gamma@mail.ru	167801427110	data/unknown/unknown.png
4	city_town_food	2237991b3bee0fcbd3d646b69c4b7b5dd82463f92990fb1f1d63eff04bb0354e	city_town_food@mail.ru	291325134388	data/unknown/unknown.png
5	city_town_cat	cb06cf3fe455f61e7dacaddaf51b0ece59565100833ca537e9ff2295d5e63609	city_town_cat@mail.ru	120200730229	data/unknown/unknown.png
6	city_town_human	63dcd768813c5f09c35a00eeb5175ecd210b18f797f6af412d6df4f7aff02be0	city_town_human@mail.ru	624235297947	data/unknown/unknown.png
7	city_town_dog	121143ba32a713a102318f552635dd621b6336eb7c2bd99fefa41f2454abcc18	city_town_dog@mail.ru	727508735260	data/unknown/unknown.png
8	city_town_bravo	189906d6da8b97380c5879406554d2a51c1720d6ba9f830e437202ecdfe88821	city_town_bravo@mail.ru	560631415709	data/unknown/unknown.png
9	city_town_alfa	32bf4784c9a329958cbe99b0740dfd0fd2a659916f165c09789d8f0f6fe44303	city_town_alfa@mail.ru	383194521929	data/unknown/unknown.png
10	city_town_delta	cdef2ff0549d1027f22c424600388c8594413a0b7c70a5835a8e7e37db05c35a	city_town_delta@mail.ru	408419464895	data/unknown/unknown.png
11	city_town_gamma	dc4d6c164030f042400d0781da2e5b2efe39341a4c1aea6a65494af383bc86a7	city_town_gamma@mail.ru	88996710419	data/unknown/unknown.png
12	city_food_town	1fc7f41df8ba33f4127d153e893ec59e18afd51af33bc2fac1b73e7722f9ad65	city_food_town@mail.ru	524831109845	data/unknown/unknown.png
13	city_food_cat	50fe312634a5ce2ef0a588620e38e7e620fdccc99aa9746668b3ef209312af25	city_food_cat@mail.ru	193815228609	data/unknown/unknown.png
14	city_food_human	7e5c9715a617e0c96ac46457e0b60d9f438025e084bf80c4076a1afc712424f6	city_food_human@mail.ru	108117369665	data/unknown/unknown.png
15	city_food_dog	7d5c52764e9f38beeb671c4bef68c6a8fe81f85ccdb19ddc42e79c9c802253c0	city_food_dog@mail.ru	890160051913	data/unknown/unknown.png
16	city_food_bravo	2de9a6d04cd16de02dc2356709af099af58ac645a419e21d4bb1182a7f02725e	city_food_bravo@mail.ru	345277513388	data/unknown/unknown.png
17	city_food_alfa	25c6129995fdaa552329854fac5f5b3b4555cc286894e332b36e9f4af02d6a54	city_food_alfa@mail.ru	549945468419	data/unknown/unknown.png
18	city_food_delta	d159d6e40a73416d1a60573c6dec77bbbf5a35ecd60db766a5edded10eb47afb	city_food_delta@mail.ru	790195432079	data/unknown/unknown.png
19	city_food_gamma	a527ce923e52198168e056a00f095124a71bf490729473215fe1e2022c23e9b6	city_food_gamma@mail.ru	599900748427	data/unknown/unknown.png
20	city_cat_town	65fc3db6f9f3fb751311b1eacfb1e62b794f55876bd43e442d5d6c377530c576	city_cat_town@mail.ru	327873363606	data/unknown/unknown.png
21	city_cat_food	2d13e39ba586e39e3ca8f792358452d8bfd9d80e082dd52210c678b1c0dd67a8	city_cat_food@mail.ru	537600982580	data/unknown/unknown.png
22	city_cat_human	cced7161faae523edbf0f6dd8276a8f2cd982fe2407b511f11c0ee15df487986	city_cat_human@mail.ru	199254939817	data/unknown/unknown.png
23	city_cat_dog	17d1cb635951d4eefa92e7b416276186f1b4c3195030bba03b53b625937cd411	city_cat_dog@mail.ru	793815078705	data/unknown/unknown.png
24	city_cat_bravo	4de2cbad5ed59a325b2dda05d103037cc991a8715ddc35987ab2f990e79a85f8	city_cat_bravo@mail.ru	181051991360	data/unknown/unknown.png
25	city_cat_alfa	a9ef2f03f878a76fd600b72654ebebdb903a3e77ea4e442006f114f7eec0c9f4	city_cat_alfa@mail.ru	565101028513	data/unknown/unknown.png
26	city_cat_delta	6ab05067763bbcca990e65a12c3dfb664d727d3006c2813a09614d2207879d27	city_cat_delta@mail.ru	474832110517	data/unknown/unknown.png
27	city_cat_gamma	7490261470be3453c4f2ad9a355e0877a66a07327deedaa32e6d7e899349b4ce	city_cat_gamma@mail.ru	605157512168	data/unknown/unknown.png
28	city_human_town	fa0a9b2e6b044d24fdc6e71c0d5e1a0a882b937c2cf952c3e6a81f8678fc9992	city_human_town@mail.ru	320214504082	data/unknown/unknown.png
29	city_human_food	c352eddbc24d810c9f35a246c18b602dd6a3e95e119b1573652ede3856b745d4	city_human_food@mail.ru	407363149919	data/unknown/unknown.png
30	city_human_cat	d0b9e549e61d1a1ccf0a92e4f02ae3ab763422ca17c50cd421863a58dd1ac7de	city_human_cat@mail.ru	472806548379	data/unknown/unknown.png
31	city_human_dog	59dccf42f4e7f45f160433b42fc9025c7406a5472d21c9741785ac3c94cd1358	city_human_dog@mail.ru	140389582748	data/unknown/unknown.png
32	city_human_bravo	9c641cb12f5629a851e8d982875894cd1f91264bcbd83a24c59485707243dcee	city_human_bravo@mail.ru	193303932659	data/unknown/unknown.png
36	city_dog_town	7edfc9222756536a9736bc6ff2a23b259b2bc783bafde95c5df070ef6e56f5f1	city_dog_town@mail.ru	125784959179	data/unknown/unknown.png
37	city_dog_food	1b059e5ca346f387c2298b8df52f31b50344f0f70688fe521f5698ecc7a21418	city_dog_food@mail.ru	736951559331	data/unknown/unknown.png
38	city_dog_cat	cd85fe4a27d621e514c6981956fa949abf262429675d93d158d074b7b4a92e27	city_dog_cat@mail.ru	246252395479	data/unknown/unknown.png
39	city_dog_human	4910fea7d55a1172d8b091cb09f9c1fdb9701ae44202e8c99edb5f2a50242c47	city_dog_human@mail.ru	689863971579	data/unknown/unknown.png
40	city_dog_bravo	426624cb8a69e11b12b328f727d2cd5fd5fe3af96e7340ca18a22760aca04f7f	city_dog_bravo@mail.ru	519611759000	data/unknown/unknown.png
41	city_dog_alfa	7f1f9e0785c2fd05fb6b86af0978569aa87a56422a49fef48327ee646e6cb626	city_dog_alfa@mail.ru	723664845476	data/unknown/unknown.png
42	city_dog_delta	24d337d2edaed9c2546543c990a6d8790db67be48e387e35bc422e41222b6f90	city_dog_delta@mail.ru	513941788652	data/unknown/unknown.png
43	city_dog_gamma	8ddacdbde8fb10835ae68084548cd5e2d84b8db1d35cc2684d0b879f0d162d13	city_dog_gamma@mail.ru	654201803330	data/unknown/unknown.png
44	city_bravo_town	803e5103cae2a2259e4442eb28d7ee3ccb5127603b8d59424de94a359b4c1258	city_bravo_town@mail.ru	580306669782	data/unknown/unknown.png
45	city_bravo_food	4b2f2cec4dfb014f0b4bc201dd318e58539184ad6540ed04292df99cdd5c5e90	city_bravo_food@mail.ru	595727176888	data/unknown/unknown.png
46	city_bravo_cat	494d9bc92a6a4cabb9c71f5bf89a00c2155e125b986ec99821feb650e6c7b24d	city_bravo_cat@mail.ru	637264938605	data/unknown/unknown.png
47	city_bravo_human	fefb64426dbdd86d0c13577bc00e378518171a1b09587646dd93ed94f295ad89	city_bravo_human@mail.ru	486547561756	data/unknown/unknown.png
48	city_bravo_dog	a1ad0e10a6dd34f99575304e821af20dbab26ef7e4a65d1e7e16b68aed6503a9	city_bravo_dog@mail.ru	256121620918	data/unknown/unknown.png
49	city_bravo_alfa	146d7f775d5161a4f86625401ad2bba0c820edd48296390048d804efdfa10463	city_bravo_alfa@mail.ru	282087503904	data/unknown/unknown.png
50	city_bravo_delta	0db5c94a380ae10eccf86e7ae98a6de56558bb9c0e993b9560ff8936d4bc807f	city_bravo_delta@mail.ru	879760220959	data/unknown/unknown.png
51	city_bravo_gamma	63f4289ba569d04297ad829fe099690bb80ab717d171f54468bfa97630b93f9d	city_bravo_gamma@mail.ru	253970975605	data/unknown/unknown.png
52	city_alfa_town	b5b018a3f59bcd666645dc573d34db0b92e5880e16c918a013e759e7a144f4e2	city_alfa_town@mail.ru	232830846180	data/unknown/unknown.png
53	city_alfa_food	fe8d37e8f81dfb1fef9c8241509a19ee5497a71ea3842e4abbab818ed78854b9	city_alfa_food@mail.ru	528822487100	data/unknown/unknown.png
54	city_alfa_cat	f7d9dae5cca0fc5624ae703cca8a788204b4a30af4a7e77def22644bfd8cbd7f	city_alfa_cat@mail.ru	367602146530	data/unknown/unknown.png
55	city_alfa_human	af2b180f4ed96dbf48c0f5875048c702406377ccfdcc46f55766fa52e8f3cb79	city_alfa_human@mail.ru	129614341854	data/unknown/unknown.png
56	city_alfa_dog	6b00e5ae9b9a25469511aef4b8e5300bf08f1afbe557a15798e65d80589e695c	city_alfa_dog@mail.ru	395688325193	data/unknown/unknown.png
57	city_alfa_bravo	5f07a6b1826f71377b39ac9f69ba0003e2085f1e70241b7a363a1585239b778e	city_alfa_bravo@mail.ru	520396076996	data/unknown/unknown.png
58	city_alfa_delta	fdb0087ce08024f76a79b67ddea245ab10358c5563f20889efafb17c21e981e6	city_alfa_delta@mail.ru	602978088902	data/unknown/unknown.png
59	city_alfa_gamma	40b6b3fa5ff42652f36fe629970e699148c948a21138821615b3b29fe56848ad	city_alfa_gamma@mail.ru	350224833293	data/unknown/unknown.png
60	city_delta_town	97fbfbe6f402740c3acf7a4a7f963298429337b5e5a19961c2c69bc30214f82f	city_delta_town@mail.ru	477786546846	data/unknown/unknown.png
61	city_delta_food	f78a0aee3d06bdc5d9962a547584c244d11af3b3563dc26354e10d229bdf087d	city_delta_food@mail.ru	231233346385	data/unknown/unknown.png
62	city_delta_cat	5d433d006cb17e6c14fcd599b8d1ac5124f057f097103d801caa8acbcf2a57a4	city_delta_cat@mail.ru	334917844614	data/unknown/unknown.png
63	city_delta_human	2e4e1fdd7ac3e4b37871565b0660e37d647889ce95ed075721362e7690f41186	city_delta_human@mail.ru	711360560395	data/unknown/unknown.png
64	city_delta_dog	502e3b9883bb132680c4712948626bd29d2d0f74a581e9ea943afbcce37b8882	city_delta_dog@mail.ru	305313049248	data/unknown/unknown.png
65	city_delta_bravo	9d7d2e38294bf0ca681603723b9abc635fad2f209e8b6c9e8c297a573baf17a8	city_delta_bravo@mail.ru	326096980593	data/unknown/unknown.png
66	city_delta_alfa	603063bafd83b33696d79d11a6b954e7d3f10b07cfe23d1770689936d08a3903	city_delta_alfa@mail.ru	396884221743	data/unknown/unknown.png
67	city_delta_gamma	676a8e43abe16e084876905d173db336c9502dfebf67656557f463efff47cbaa	city_delta_gamma@mail.ru	799007214859	data/unknown/unknown.png
68	city_gamma_town	c33d3279b9bc4ed2b7b2a46b616317d5810d1cd320a5e85de59c9b0e3660379c	city_gamma_town@mail.ru	383988194475	data/unknown/unknown.png
69	city_gamma_food	d1e4ca20dba9aaee78af4d4db9d765366fba3642781ed7afabfc765b786e3d34	city_gamma_food@mail.ru	133879227963	data/unknown/unknown.png
70	city_gamma_cat	c6a68036d0b1a6cc7da37e4a5adce69951ee7221dbc6ed26e4c8bd74168662a5	city_gamma_cat@mail.ru	301063602292	data/unknown/unknown.png
71	city_gamma_human	aa5e7c5203e0f15e621543e1e77a5e9fe4e95b9741c1b26afd63de06245f6e98	city_gamma_human@mail.ru	268578770846	data/unknown/unknown.png
72	city_gamma_dog	005344afb6c7a28b2917993cdf69dd02b21bb4022bcfc33fdbaa200a58476a94	city_gamma_dog@mail.ru	858079025321	data/unknown/unknown.png
73	city_gamma_bravo	eb005ab460f6c6a8e16fd9ab33e4a6e02d60e28b17eb1f8bb589b0c75bce19de	city_gamma_bravo@mail.ru	879988534123	data/unknown/unknown.png
74	city_gamma_alfa	0187e4bd208d5f32cc7275d00cf172de9ebfc03b3c307f7312a4522a7c64f11f	city_gamma_alfa@mail.ru	463868132825	data/unknown/unknown.png
75	city_gamma_delta	ab9fbe08bb3df2a32df1dc83138d1e658c61a36339515e491608425b8fd5df9a	city_gamma_delta@mail.ru	480614273256	data/unknown/unknown.png
76	town_city_food	31d3083d6558805bc24e118304093adf1a964770e20dbcfbead4bba6b24b0f03	town_city_food@mail.ru	646838665031	data/unknown/unknown.png
77	town_city_cat	19c24989bdbe47310d89b366cc705e16ceb1f515784919f2829f18793c37f8fa	town_city_cat@mail.ru	887062330611	data/unknown/unknown.png
78	town_city_human	d281be90ae357dbf989059a4c85df50fcd211c9cabcf313695baa0792e16b595	town_city_human@mail.ru	522619298759	data/unknown/unknown.png
79	town_city_dog	9abb26a011d9ace82ad18186977eb29d753badab05f2e84c124cfe14f5d2cf3d	town_city_dog@mail.ru	290325316643	data/unknown/unknown.png
80	town_city_bravo	6ffc2b6a46bf1d93163a347987aece1d9dd1d14aed9a76b2923859162ff076c7	town_city_bravo@mail.ru	471183736695	data/unknown/unknown.png
81	town_city_alfa	e542a9a542e19ea390ec146545a4a760cf91e400c10c42c542568be7935a116f	town_city_alfa@mail.ru	443085497393	data/unknown/unknown.png
82	town_city_delta	85f1df8d95e81d0a5a5b5261ad43777dc7be74205cbde927d94840b168f77a10	town_city_delta@mail.ru	84561347550	data/unknown/unknown.png
83	town_city_gamma	bd7915bc1cef0965e4ffbc02161a5cd5bb63f521b5c173fb857ed8960732a7fa	town_city_gamma@mail.ru	881218071971	data/unknown/unknown.png
84	town_food_city	a8675bd0b2c6c9d4119159457b16cec471d15ac3b641c47c537131e00e66f443	town_food_city@mail.ru	98258759823	data/unknown/unknown.png
85	town_food_cat	11532354f37d1ede07d96c036562fd7e7645e070a8ee6ecabd93ccbc2cef0e3c	town_food_cat@mail.ru	474741273099	data/unknown/unknown.png
86	town_food_human	6819776ed55a771e3f8bd91e9ae6006c7376e6c0e22bebdef58012770fffe4e1	town_food_human@mail.ru	379597664008	data/unknown/unknown.png
87	town_food_dog	4439408dc50b9ecb8a6a914507ac8d66a8a778423da3cd954d60869e52fd22a3	town_food_dog@mail.ru	301610127395	data/unknown/unknown.png
88	town_food_bravo	9858999616a18208175b605d1cfe49d88124c3e6bfae2c142b08deb1a1fe94f1	town_food_bravo@mail.ru	292321452544	data/unknown/unknown.png
89	town_food_alfa	f4dbf302dfb27572fdac7a7d53b50e0c8427408ff798e6442373d99f41fe5c9c	town_food_alfa@mail.ru	413149041930	data/unknown/unknown.png
90	town_food_delta	cf41ab84ee80771b7b176973cd47b538560f7d1517cfb7d64c7f6d1cad24ee17	town_food_delta@mail.ru	671156211494	data/unknown/unknown.png
91	town_food_gamma	855c5452308296f18470ab900efbbe3f38c6018c73883c2e2fc5f3606de37c95	town_food_gamma@mail.ru	805972350612	data/unknown/unknown.png
92	town_cat_city	547fe9160c22892465c685bd83a9dc61148a9e567a2f94101518b61fe9eab620	town_cat_city@mail.ru	585168170165	data/unknown/unknown.png
93	town_cat_food	8db1381484655a5b8b95ee9791a6ddf90fab7cee74132b3da8de287d12ec76d8	town_cat_food@mail.ru	352627651382	data/unknown/unknown.png
94	town_cat_human	d873590c4158a6d02139e011f4976aea94e099e985c576b9887d88c1e56b1d9f	town_cat_human@mail.ru	661719787720	data/unknown/unknown.png
95	town_cat_dog	88487941ac4c719c61a6554a5619bf11b418a7ac7eaf8889d9c07c79cebf467d	town_cat_dog@mail.ru	730504068641	data/unknown/unknown.png
96	town_cat_bravo	e1e2d268707aa882960ae66d7ba00de75005f471ad529c5dffbfd847844ab64e	town_cat_bravo@mail.ru	126480659666	data/unknown/unknown.png
97	town_cat_alfa	6ce1d0163378a081a4d68c2236894d6d9853b7ab52592f94bfb9041fb6bdcb0c	town_cat_alfa@mail.ru	886604589299	data/unknown/unknown.png
98	town_cat_delta	7ddae7605b580df3d376794ae3ec90a93c86e825fa4dc98d8f645857630c6a51	town_cat_delta@mail.ru	220858987682	data/unknown/unknown.png
99	town_cat_gamma	6da5eb09381e5f23bb49c505871a287d2ecfcdac5e5d9986bd1c261d0d449ef1	town_cat_gamma@mail.ru	804143435796	data/unknown/unknown.png
100	town_human_city	add39889510668c4c0b11bff6dbd098f79653e3a95291bd05b6d25fce4440934	town_human_city@mail.ru	584760081383	data/unknown/unknown.png
101	town_human_food	294f9c984b5b8ab59d876871e6accc764fcf687929f28254d4a989635d61886b	town_human_food@mail.ru	547039650859	data/unknown/unknown.png
102	town_human_cat	236dc1855be97236101729ad9cc6cfb834640d964ddd33afd7a456899d115110	town_human_cat@mail.ru	345012055254	data/unknown/unknown.png
103	town_human_dog	dc18f1c301bdf2354c3715c712f7e282bcbe18d38b1abcd1513871548b63050d	town_human_dog@mail.ru	318279923038	data/unknown/unknown.png
104	town_human_bravo	d692c610e00549aa2a3bc1da8dfd512315c139c4f69782a04b1074c6509f3f52	town_human_bravo@mail.ru	312378713620	data/unknown/unknown.png
105	town_human_alfa	adb7df271bf189e86f548fe4caca0ccab190d22f854909304dc48384e662d9a2	town_human_alfa@mail.ru	759538133341	data/unknown/unknown.png
106	town_human_delta	b9adfd41db63501f00c215c44985267e9f79c419ee08e382a8646da1f03f48c1	town_human_delta@mail.ru	233095496171	data/unknown/unknown.png
107	town_human_gamma	e77c33f35bfd571dd4e8e5ea9b4ab15ebd6a62b3c30893516c5db25c03be0c23	town_human_gamma@mail.ru	860008552059	data/unknown/unknown.png
108	town_dog_city	9179fd27d5c89832b492bde79a27575c8bcf2d6e45c51052e3c7ae669feaf30b	town_dog_city@mail.ru	486473991953	data/unknown/unknown.png
109	town_dog_food	3d86b3e36b01be23f42210c5be9dd807b1cd96a98b913b0ea70919225c2ae487	town_dog_food@mail.ru	474893279765	data/unknown/unknown.png
110	town_dog_cat	33cc81142c89a0129eae4f3681b889fce8d78878d9159b8430845698abb6231c	town_dog_cat@mail.ru	325965888048	data/unknown/unknown.png
111	town_dog_human	7453f9564e2b96180c0fde1acf2fa1180506162af4b3b6beb1fc083c97e06926	town_dog_human@mail.ru	364872176866	data/unknown/unknown.png
112	town_dog_bravo	b79fc944ecc2cd38c22956bb0facbb41c8c1500a33c34ac54567e40dfb3f194e	town_dog_bravo@mail.ru	318813237806	data/unknown/unknown.png
113	town_dog_alfa	61f1cc7f58fc33f755fde2f1afef7c8a71dd47e15c6399082c2b150bcb5f6a69	town_dog_alfa@mail.ru	205820078474	data/unknown/unknown.png
114	town_dog_delta	b7c35ccd8ae99c9e4d865218b85a533170cfb4b0059e9dabd3ccb6bc0399bb3d	town_dog_delta@mail.ru	342147549182	data/unknown/unknown.png
115	town_dog_gamma	e2f82af74103d130ffb7386fe6541ea04546eca86ecbd9a22fda07b6fc39cf22	town_dog_gamma@mail.ru	672868406865	data/unknown/unknown.png
116	town_bravo_city	519beae8cefd5849de9b74d95d0993ea90b96877b4879c3e5fed98439e795af6	town_bravo_city@mail.ru	434041547385	data/unknown/unknown.png
117	town_bravo_food	3bde7d398332d54e957ab9c1f4f2db0dab13ef3fd9b425601c72e6bdcc28fa26	town_bravo_food@mail.ru	860411897210	data/unknown/unknown.png
118	town_bravo_cat	48c74502f435f1c6f5ec9e08c3423c1afc25af0a262aa556038a6440ac68d861	town_bravo_cat@mail.ru	580967948067	data/unknown/unknown.png
119	town_bravo_human	16612ba14817b4120d2ac0d349bf44acda46574abf3c3c60e4febd9cb52f4226	town_bravo_human@mail.ru	163414000813	data/unknown/unknown.png
120	town_bravo_dog	b51b88b82cd0beacd0eac3f2ebbe21114a7e4a3d6ffc482aa310f758aec3a6de	town_bravo_dog@mail.ru	454321192600	data/unknown/unknown.png
121	town_bravo_alfa	c48f7a7392b2f6d2a86548acdbbe95bb0ab715b91f13d531bf685baeb8b08a10	town_bravo_alfa@mail.ru	440024412004	data/unknown/unknown.png
122	town_bravo_delta	c3b0b471fcf85e129f0d8df3c439593495f48534a7b3f744b0cb5c3bafcd70d2	town_bravo_delta@mail.ru	222916201059	data/unknown/unknown.png
123	town_bravo_gamma	8dad6616fdf4978afc5b239f7805d2e9d9dd4b752e26ca2a9f765713d8160d83	town_bravo_gamma@mail.ru	538871098583	data/unknown/unknown.png
124	town_alfa_city	44abfd46d4958deba57b68a895745320ffcaa2b98891a88c9ee1915cbc480f6e	town_alfa_city@mail.ru	868198319574	data/unknown/unknown.png
125	town_alfa_food	67c22a89211970d3b06ecdc31cc80b10cef10c1cd9d117ed64ec6ed146314e32	town_alfa_food@mail.ru	93161511932	data/unknown/unknown.png
126	town_alfa_cat	983626dbcd2eec3a76d746ff27ba799830cf1774d998ebb690582ce5ee82802a	town_alfa_cat@mail.ru	700511219119	data/unknown/unknown.png
127	town_alfa_human	39b3d79aa44a97310dddbbbda452b9ad8a1980490cc971f4bdb3843efba4ab92	town_alfa_human@mail.ru	888174436413	data/unknown/unknown.png
128	town_alfa_dog	090ff45518c31b974b10a20cae6a817844675bc4a357ea5bed169b4e67203cd2	town_alfa_dog@mail.ru	842956493675	data/unknown/unknown.png
129	town_alfa_bravo	5a4d19b48d43b3bf292b7b405d5b505fbc1fb800804f9047944075c28c5b3561	town_alfa_bravo@mail.ru	839755636551	data/unknown/unknown.png
130	town_alfa_delta	510293fe677fd22828754682da037e71808fe3d917319c65df91fa63b418d9bc	town_alfa_delta@mail.ru	397569776736	data/unknown/unknown.png
131	town_alfa_gamma	c50709af7650a19ec7e1b3ecd22c3c8248cf64169f975a72bd705117834a5568	town_alfa_gamma@mail.ru	772291148583	data/unknown/unknown.png
132	town_delta_city	3590b4a55b9ba9ef791c5eb3f6c7b93d7e180bb7cdc7a0bf764e36eeb2e090d2	town_delta_city@mail.ru	592808589648	data/unknown/unknown.png
133	town_delta_food	176a6304c3af0ff7a1255e2b7af32152ebb871a0f172f959dfecc6f8dd160892	town_delta_food@mail.ru	326487784129	data/unknown/unknown.png
134	town_delta_cat	4cb554381268a997eac8dcf55df0d193763baf408b9ee46d944a410cfab04651	town_delta_cat@mail.ru	174895670135	data/unknown/unknown.png
135	town_delta_human	309778d1826b66ea01c14f906181251e8c77eb2dc24c6740c4e2bb26f785da33	town_delta_human@mail.ru	525721264724	data/unknown/unknown.png
136	town_delta_dog	066bdb08d6ada22af649ca4e16faf29880b6a0e014098fcbb5a51ab1dd2d9d3a	town_delta_dog@mail.ru	191532813393	data/unknown/unknown.png
137	town_delta_bravo	c375098420e35a78a789289a542d72c123f8322d1047dad62549280bc0b354f9	town_delta_bravo@mail.ru	745706610945	data/unknown/unknown.png
138	town_delta_alfa	183987db18bb3d82bb461af14a75c44eec8cf449c09bf0b29eda63d8e40f2183	town_delta_alfa@mail.ru	714946658466	data/unknown/unknown.png
139	town_delta_gamma	25175314367ed3a5e5f091b907319171fae6701f32f090dbe1ea493182ca7684	town_delta_gamma@mail.ru	327540819068	data/unknown/unknown.png
140	town_gamma_city	f6bc5bf586f12a5fa94ebbd5fd08a43b524cc9e473ea152317dcc2388256d7d8	town_gamma_city@mail.ru	201844248097	data/unknown/unknown.png
141	town_gamma_food	da66237175ca16f272e9f9806b59340a907f3547ac0c82366466d066b4ffe18f	town_gamma_food@mail.ru	295919473574	data/unknown/unknown.png
142	town_gamma_cat	330fcf89cf01a9802363c0973c3e0a17cdb49f5fde1e19881ae7318511e0caad	town_gamma_cat@mail.ru	874713333375	data/unknown/unknown.png
143	town_gamma_human	65288b1fe609c11e283e1679c42bbecb6657721df771f753d81a167174dc68bf	town_gamma_human@mail.ru	154108336325	data/unknown/unknown.png
144	town_gamma_dog	5995a97ca74ec8ac21f58a9ad6080b33fd7d579c04087e6f88ad919b03580040	town_gamma_dog@mail.ru	524464054457	data/unknown/unknown.png
145	town_gamma_bravo	3e336dad5d608b1a19c74a73c3bd950cff9a4d9d8dbe276f006734667e334b69	town_gamma_bravo@mail.ru	226460932683	data/unknown/unknown.png
146	town_gamma_alfa	c41c3dd082255b125722072b73ba6984b71fa36a94719057bce3d84abd353266	town_gamma_alfa@mail.ru	251179509764	data/unknown/unknown.png
147	town_gamma_delta	f772c0032b3c90b0f033848022bdb75cd8252106e46a27e1ea589e980706cd9a	town_gamma_delta@mail.ru	450856778724	data/unknown/unknown.png
148	food_city_town	9a54866fa1b52fcd87600b0607a4fde21fc0a73e4181a722db754254891c05b7	food_city_town@mail.ru	361591495158	data/unknown/unknown.png
149	food_city_cat	718ed813a6c70976e2a4c267314f8a92595cfa31c07a0463d01bab7883e0fe20	food_city_cat@mail.ru	355252046283	data/unknown/unknown.png
150	food_city_human	c1929dff9fc9ca00c09ddd9fc1b4942f168deda8855cd32e64b82091dc7bbd1d	food_city_human@mail.ru	309085442925	data/unknown/unknown.png
151	food_city_dog	ad7f30e9299d3e87d5bd940135324d4db7de9dad58aa464b144d3f7cbf9a01e7	food_city_dog@mail.ru	208587844681	data/unknown/unknown.png
152	food_city_bravo	7b4bb26cf106d2853b0dfbe8e32976823a8a1fcf6c4f236f0fbc1b9c9410348e	food_city_bravo@mail.ru	499278194414	data/unknown/unknown.png
153	food_city_alfa	ec888b780aa6b487244f252e91cbd59efd6f4518617b0bcc16896481dc51931d	food_city_alfa@mail.ru	720742306998	data/unknown/unknown.png
154	food_city_delta	94cdd2f4fe9566ec17546637ea00204161581f85748ff8b7e5fed8bf2c0e7c56	food_city_delta@mail.ru	749532541353	data/unknown/unknown.png
155	food_city_gamma	7fa09a8a32ab06709243ab4ba7eb2e7bf24ecb83c6ac3e530927b44f78bc79a8	food_city_gamma@mail.ru	354556552345	data/unknown/unknown.png
156	food_town_city	a4f4fa4b1a6ad631256bef0e3519d6f2a27f62c286d65d56a6eb32f15ed98cb4	food_town_city@mail.ru	362389646971	data/unknown/unknown.png
157	food_town_cat	fcb75958e7bd7b7d9784c46a30a63d5565386a32d9c58f13ab489c60389328f7	food_town_cat@mail.ru	567306538392	data/unknown/unknown.png
158	food_town_human	d97a4d29243eb9ffa18640f41c484230d8c323958c9ca0a54262aecd20186dbd	food_town_human@mail.ru	249815443571	data/unknown/unknown.png
159	food_town_dog	c15ff1b4bb2c75c64834dea7ec23e16b299cdc151e53be9ce3e2c4332ca004a3	food_town_dog@mail.ru	240566681583	data/unknown/unknown.png
160	food_town_bravo	e9e2f05a8fc41f35e7c39ae67f1f86eb9b719b197131b21c8af4538bd0b8c4a2	food_town_bravo@mail.ru	883443093963	data/unknown/unknown.png
161	food_town_alfa	ff0bb63824c31d2ab0e80090149b0c13645cfb6ce92e9795f4a2b83b8da7e2f0	food_town_alfa@mail.ru	871504451522	data/unknown/unknown.png
162	food_town_delta	3831053ea866c0bf1ea17ceb15397927308d6f49a7ede3a40122aef59a326e20	food_town_delta@mail.ru	94739958451	data/unknown/unknown.png
163	food_town_gamma	114d2f7e9102c085e483eca66c959e3fb75b990962eb08ed0462bf70fd8caaa3	food_town_gamma@mail.ru	848614611130	data/unknown/unknown.png
164	food_cat_city	d2b9c16e65338f91658993e5dace301a21a4168ac3fb18d12c198092ac5270d0	food_cat_city@mail.ru	343957048755	data/unknown/unknown.png
165	food_cat_town	b6010ae90491a79b625bb2b0965389c5e08004a39351eeb41d1af51e9909421a	food_cat_town@mail.ru	224541151057	data/unknown/unknown.png
166	food_cat_human	1ab437523fe62e5b14e7e834e1ef4a9b4246ce33a75d6555d316923a393da1a8	food_cat_human@mail.ru	598308163344	data/unknown/unknown.png
167	food_cat_dog	1107139a68030ff9ff63e7f838cc784cf8f6f27487994e383c96d102b9820b4b	food_cat_dog@mail.ru	665052727148	data/unknown/unknown.png
168	food_cat_bravo	5e32be8fd03bac0a76f3a52a5be077b72880a66b4e9061548e72aa64ac2488c5	food_cat_bravo@mail.ru	577989498324	data/unknown/unknown.png
169	food_cat_alfa	3d8ee01beb49c1018e417d66e3c2a5c1a60e863a97482dadfd78a5097a049a75	food_cat_alfa@mail.ru	183038517340	data/unknown/unknown.png
170	food_cat_delta	a133ec38df1468629f0a16e17d4ed1dc74a3f38ee9a5596744147efd52b59677	food_cat_delta@mail.ru	764123830457	data/unknown/unknown.png
171	food_cat_gamma	d3b645989b0655dd07d1cbadbcdb702bebd76e221c325cbef535f4630aa34b46	food_cat_gamma@mail.ru	741956910670	data/unknown/unknown.png
172	food_human_city	acdbd1c9e824d6bf63e20ce311e5f46e3fb70157d6d9b584f7b2b991743e1203	food_human_city@mail.ru	806376977545	data/unknown/unknown.png
173	food_human_town	95c6c56e0508786047c44915c2b52262e2b5809acda8f85be47db74e70f49902	food_human_town@mail.ru	202474443516	data/unknown/unknown.png
174	food_human_cat	1fa2d26ca07e9716c8e65c1380f3db52a23fcc8fad573364975df8db2faaf9e9	food_human_cat@mail.ru	455730683393	data/unknown/unknown.png
175	food_human_dog	265d9252f77b5954a20c1d6a6a7344e293284afc82d40c7e23d7d938d7e3807e	food_human_dog@mail.ru	525831279775	data/unknown/unknown.png
176	food_human_bravo	9ea3ee60f7782dc103dca2023dc760227b3a7bc6bdf525e46723f1fae015ed72	food_human_bravo@mail.ru	747724914208	data/unknown/unknown.png
177	food_human_alfa	8937e44584a1be98b5518488117f39ebbab4be749992cb99134900e782f2db1a	food_human_alfa@mail.ru	659994659674	data/unknown/unknown.png
178	food_human_delta	00587161430703cb839ab3f68d64cb7f71c8bda0f283de4330502af16e484bc2	food_human_delta@mail.ru	562364363870	data/unknown/unknown.png
179	food_human_gamma	b9ad16b69831263780b6dc1df72e010feebe78602cfc17a7ba96b8a5664edc32	food_human_gamma@mail.ru	102282341983	data/unknown/unknown.png
180	food_dog_city	16458502bd5f1f2098c596100a8b9479480c072f0521eb212894758199285d35	food_dog_city@mail.ru	657751433239	data/unknown/unknown.png
181	food_dog_town	a6c0a6d2f5eea79a76bdf77074daa1080de53406ce62e5a8c0c246731fc230b6	food_dog_town@mail.ru	670048633517	data/unknown/unknown.png
182	food_dog_cat	07aa300ac88ba4ee04a25ef119d2bcef05665f5fc1bf524d9410db5927978c6f	food_dog_cat@mail.ru	650360073957	data/unknown/unknown.png
183	food_dog_human	313acb88f031ba49da60f549b57bb3e2ef1ff3f57c404dbed7e2bfba9483eaac	food_dog_human@mail.ru	740765910359	data/unknown/unknown.png
184	food_dog_bravo	35af7b77948473ed735aeea5d7441ed30228609edb8abd3fd4e38914c7702123	food_dog_bravo@mail.ru	670279682996	data/unknown/unknown.png
185	food_dog_alfa	b1ba1a1d12645721313a3f023c032aaeec35027a8482f3244bf9697a662ed913	food_dog_alfa@mail.ru	617964196621	data/unknown/unknown.png
186	food_dog_delta	8077fae70e44ea94039e0ddb32da95628473b2616f2693cdb7292eda9751d643	food_dog_delta@mail.ru	338978841168	data/unknown/unknown.png
187	food_dog_gamma	1c38b2d80769478b5fa60c9ca3f9d8004de758de7a81c43098c7a6d9ff680481	food_dog_gamma@mail.ru	337072601467	data/unknown/unknown.png
188	food_bravo_city	901aff3ed762a1c77b282d2834e9bee28607e1e9a06fab39376abd6fb9ed0c0b	food_bravo_city@mail.ru	413846690525	data/unknown/unknown.png
189	food_bravo_town	bd3625c6f079d06325c96d81cdc340b9edfeabaf7cbfd79b4003691c65aa06b1	food_bravo_town@mail.ru	713373645481	data/unknown/unknown.png
190	food_bravo_cat	9b8f13acffd07233714cfcca4cb156130b87c0b5f97cfde3b80f20efc55e3d22	food_bravo_cat@mail.ru	704740314639	data/unknown/unknown.png
191	food_bravo_human	b2f010dffa4322c1e37c5233255b6329bb0d1b91ed157cd37a3f2a297471645f	food_bravo_human@mail.ru	540287512953	data/unknown/unknown.png
192	food_bravo_dog	db5371eec379ba98785e281731f15e8bbb506ae11fb34b26dc73d6f79a8488e1	food_bravo_dog@mail.ru	310502705138	data/unknown/unknown.png
193	food_bravo_alfa	23813cb6eceda4ae19be2765cc206eb4e7d8ccb71dc4d388a334eee85dfee17f	food_bravo_alfa@mail.ru	296492760989	data/unknown/unknown.png
194	food_bravo_delta	7e337e27b29fec5c4e963b287e5dc1cbccdbc5eb711a450d80ec4d77445d87b0	food_bravo_delta@mail.ru	263612579197	data/unknown/unknown.png
195	food_bravo_gamma	e41ec799e483569f9c791d2c13a42b59acd3087d8a13be1de0a264a046af6848	food_bravo_gamma@mail.ru	692036191337	data/unknown/unknown.png
196	food_alfa_city	7527682280aa0730b4ed386a86ae75e4be2d5f6936e4c305eb4b46686510cdb0	food_alfa_city@mail.ru	514962443814	data/unknown/unknown.png
197	food_alfa_town	38df337d9b680c425ed6017cedbe72a0bd5f88dc1bea3af650b2503bde41fb15	food_alfa_town@mail.ru	96792608158	data/unknown/unknown.png
198	food_alfa_cat	a989e7db566b9b5ea2bc2cdb8e151277bb51e2775fb27a64bc0e11461d48feae	food_alfa_cat@mail.ru	635630994444	data/unknown/unknown.png
199	food_alfa_human	3c43ac9f8d6ce88957f30c4c3f0c4b247231a028a0fb4e52c6b16e58d5425193	food_alfa_human@mail.ru	637467469660	data/unknown/unknown.png
200	food_alfa_dog	c2c2fbe15280be2dd74de790f4fb50015eb4ec79bc5a1f99b87edd552eeb9f0e	food_alfa_dog@mail.ru	716257958119	data/unknown/unknown.png
201	food_alfa_bravo	e16b70c91e0ece07811fa4e5ab5d62d4a4fa6018b248743620a9f7072b890b74	food_alfa_bravo@mail.ru	698109834294	data/unknown/unknown.png
202	food_alfa_delta	0246568e55a1d147ec2888a8a01246b874402b90ba549e6419a11a06c58cee0c	food_alfa_delta@mail.ru	376615415698	data/unknown/unknown.png
203	food_alfa_gamma	f6b6ddc1b16d03083e687fde0478ae5244bf4cb7824f9341a9fc829b83a848ab	food_alfa_gamma@mail.ru	133940261728	data/unknown/unknown.png
204	food_delta_city	eef3ba7e1f50393434cd0867313ef69c98446c3b5c11a400181126a00c9f47d3	food_delta_city@mail.ru	152935613203	data/unknown/unknown.png
205	food_delta_town	f44322e42133f4ba077dbb2406999ccc61ced36c9b1fb6c646aa159c335f452b	food_delta_town@mail.ru	506990747902	data/unknown/unknown.png
206	food_delta_cat	bcd9ce6352998d791c0f2877ca4b1360769704cb545045d7acbbc2e8c4a2e14e	food_delta_cat@mail.ru	158274198005	data/unknown/unknown.png
207	food_delta_human	3fb28b8ca937a815588ee73042f74639ca812abbe9874863c91396915fd5c9fc	food_delta_human@mail.ru	415965480172	data/unknown/unknown.png
208	food_delta_dog	701423ca9c1e76cb247fd8e5dc2c594b56f7047eae20d3a73091b2134ddfa9e5	food_delta_dog@mail.ru	727957699174	data/unknown/unknown.png
209	food_delta_bravo	0d8f80c2c616f5f2d937a98e72b7f6df9062847d49426a8f3663f0d32e1d3a26	food_delta_bravo@mail.ru	587441452511	data/unknown/unknown.png
210	food_delta_alfa	8fd3eb374851b8709022b05b31ace485c915ee33d8b4d62893018701238df56b	food_delta_alfa@mail.ru	583544155709	data/unknown/unknown.png
211	food_delta_gamma	d002c9c82a554f869381964c480a392a2a79752ef58656be4fcfbd1a6a8ca99e	food_delta_gamma@mail.ru	767689253125	data/unknown/unknown.png
212	food_gamma_city	166ccf544d1d13b71028458b43fcddd02ad4ca5915d6a733e95925088d13607e	food_gamma_city@mail.ru	153842838145	data/unknown/unknown.png
213	food_gamma_town	f9ac3c98c348570aba4d72dcbb1e9b9a6d165ce9e08cc0c10aabef62c0fe8de1	food_gamma_town@mail.ru	103062510429	data/unknown/unknown.png
214	food_gamma_cat	89ad2899b0b562bf7593be974c51c769fe04ee61aebb37c574593c2c13270830	food_gamma_cat@mail.ru	821858266099	data/unknown/unknown.png
215	food_gamma_human	aa23940c3c9658eb354fc995c7edc3f1288d43a088ff37cae285d006002e4126	food_gamma_human@mail.ru	553790600336	data/unknown/unknown.png
216	food_gamma_dog	c21a46ac87bea25c76d140fe3cfbf587514cd921b81e779da64c42cb795174ec	food_gamma_dog@mail.ru	792928216772	data/unknown/unknown.png
217	food_gamma_bravo	bd7351cfdd877f0ab53f944587802364925cc2bf78ea97afc09b75cecb362b52	food_gamma_bravo@mail.ru	389432282424	data/unknown/unknown.png
218	food_gamma_alfa	ea1c14dfd75516d464922b49364c61809b465a208f06fc14939585a1ebd10337	food_gamma_alfa@mail.ru	193914267031	data/unknown/unknown.png
219	food_gamma_delta	4bfdec5a81a8b8b78812066638f10c1ba01533845ee75390d077f1c862e0550e	food_gamma_delta@mail.ru	841586077247	data/unknown/unknown.png
220	cat_city_town	084ef7466b6ee189640bf86e748a4a1e236783cd9fe9f6e288d3e7c51e227668	cat_city_town@mail.ru	260304523065	data/unknown/unknown.png
221	cat_city_food	4f4d7d3c2db92ffeddd270c164123e8e387483d9ee3fc9f7b46645cf572a5921	cat_city_food@mail.ru	551746666961	data/unknown/unknown.png
222	cat_city_human	5081165855288be855cf2bc5ad89a7dd6016c595e89eafdd9a2ec9807f3ae0fa	cat_city_human@mail.ru	712948850592	data/unknown/unknown.png
223	cat_city_dog	0c9a076db27a0aa43d68b3d674e0e50ab43394cb133bcde61ab9b86f31959c8f	cat_city_dog@mail.ru	88629068297	data/unknown/unknown.png
224	cat_city_bravo	d6f380338bec17f33610e7e042b2e3c2ada178f1f91706bca64755eff7c90fac	cat_city_bravo@mail.ru	233757576178	data/unknown/unknown.png
225	cat_city_alfa	2339dd36e57fe1808a2c527c43e1b9ed2d7e8d399b0c092d74a53f55f7024716	cat_city_alfa@mail.ru	734220048201	data/unknown/unknown.png
226	cat_city_delta	a33a4aac6d238fcdd8c752e8e6eef6296dd4546655a9dd38bf7f4784a77e6f9e	cat_city_delta@mail.ru	716668098517	data/unknown/unknown.png
227	cat_city_gamma	aecfa7c2da7134e546c9fbbd6576170cad7bebada2d68d2f8ef61839e0e8359b	cat_city_gamma@mail.ru	571814419490	data/unknown/unknown.png
228	cat_town_city	bdf36cab66491a10d8f48a57a6218d229d5d3ebab1624d90c5e0cc9c39f30186	cat_town_city@mail.ru	171752119009	data/unknown/unknown.png
229	cat_town_food	d14632959f448844ca4bafc59b6ae49c56bbed4478f7173b60f1b8136d3a789f	cat_town_food@mail.ru	93827594719	data/unknown/unknown.png
230	cat_town_human	a7b50ca929d023f565f2e5e1fb250eb9ada25f0c09cd34d44da9cafe7aabd8c9	cat_town_human@mail.ru	320823862898	data/unknown/unknown.png
231	cat_town_dog	76237d2fdb100ed5e87c8397e05ca9b1d3dbfe868665204852e1337fda4f62ad	cat_town_dog@mail.ru	859017701404	data/unknown/unknown.png
232	cat_town_bravo	f3902410f9873555c5a611922c8611e421fbdc174c54b512604340729f76246b	cat_town_bravo@mail.ru	99197004337	data/unknown/unknown.png
233	cat_town_alfa	f108bf3903ddbcd43786fc2f9b9a6687427076ed99fb312e2bfb4866a1dc2797	cat_town_alfa@mail.ru	593360936851	data/unknown/unknown.png
234	cat_town_delta	093a2ab28b5f9b17214ba8245337db52ae091502e827b8909adeb9338ac60f2a	cat_town_delta@mail.ru	419043363825	data/unknown/unknown.png
235	cat_town_gamma	a96094332122282b1e21b0ff9afc397dad229500861f956d872f45a2b8ece8a4	cat_town_gamma@mail.ru	385767901634	data/unknown/unknown.png
236	cat_food_city	00ec938ed92f1f09585dd62151a2a51fd6f0f5b6b3dabf81ed1827cf4dfaca30	cat_food_city@mail.ru	133265298102	data/unknown/unknown.png
237	cat_food_town	c6e6add2ae269d34b2e52150804b13fa82da78a9198514dd5c8b6f63e2254464	cat_food_town@mail.ru	654657885825	data/unknown/unknown.png
238	cat_food_human	3ef2c4ebfaa0d0aba4da584855ac7fa529b03f5158d968cf28384019ccda37a5	cat_food_human@mail.ru	331520139173	data/unknown/unknown.png
239	cat_food_dog	01917e4595446c6f80549f7d4b70722371ac7e8ec14747d432f11d82a65b2c75	cat_food_dog@mail.ru	391819969715	data/unknown/unknown.png
240	cat_food_bravo	78c90a97440a2c9a8df54ddb39e6b480921da811ae1379dec9a61ed11501ac4e	cat_food_bravo@mail.ru	427963830299	data/unknown/unknown.png
241	cat_food_alfa	ccf25b2947c76200c15f075ce642588720c1dfb5fc48eb68caae5448071f673d	cat_food_alfa@mail.ru	718511374783	data/unknown/unknown.png
242	cat_food_delta	e23369d3b6557bee004cf520f1d2385735a2fc3ee17ac57ae145915afe2a8ca5	cat_food_delta@mail.ru	518225054443	data/unknown/unknown.png
243	cat_food_gamma	e88fe4cdcf7648092b06c00b4195c9f5180e8133bac6b87d517d09538895e956	cat_food_gamma@mail.ru	107409141041	data/unknown/unknown.png
244	cat_human_city	895054263ad2b7b99e1aac30d98bb88a916c77f041a456f07208a2cc1c83c5ed	cat_human_city@mail.ru	251787210808	data/unknown/unknown.png
245	cat_human_town	3953204dd1165731c64d1f45c2aa70b12a5866a761fa44696da8213cbe6fa26d	cat_human_town@mail.ru	477562840690	data/unknown/unknown.png
246	cat_human_food	48971d99e0816f914c99014886bf6cf0c7fd155a0ebec9ebd2f3c7df3af9b42c	cat_human_food@mail.ru	844255061663	data/unknown/unknown.png
247	cat_human_dog	dc282d12610ffef728d6b90bb988700680a203236f071548dc715bd8138c03aa	cat_human_dog@mail.ru	698117563459	data/unknown/unknown.png
248	cat_human_bravo	c547791191104513c5b202dbecd2629215f2a5abc51c3b832fde5b117dcbe795	cat_human_bravo@mail.ru	539585283532	data/unknown/unknown.png
249	cat_human_alfa	b8f5f7ac047e392234cec53d46e3ea1cc7c3b99eb2629ab84f99a743f5fb061c	cat_human_alfa@mail.ru	277998159424	data/unknown/unknown.png
250	cat_human_delta	fefbea82f4b8118ab3d9952c139e10f7bffea054de49bac214afc8a506250d3a	cat_human_delta@mail.ru	748578923274	data/unknown/unknown.png
251	cat_human_gamma	21cde28a4e91524f77e96e92dd54e32159e48c7d41e3f0210e4f8cf0d1a3f46e	cat_human_gamma@mail.ru	291431805650	data/unknown/unknown.png
252	cat_dog_city	fea4eac7ac15b13a1099efc57adcd6659794a2aecdf95cdc60cfca14f94f9b0a	cat_dog_city@mail.ru	427310378684	data/unknown/unknown.png
253	cat_dog_town	9f1b031f1729adbddb59dfa4234f9a8875427fb41ba98c778c3e1955bc2b53ed	cat_dog_town@mail.ru	636801508133	data/unknown/unknown.png
254	cat_dog_food	bc77e7e1aacbbca9afba21ddb0cac5de94c9be2fba60c66ff108624aa0585027	cat_dog_food@mail.ru	761354676138	data/unknown/unknown.png
255	cat_dog_human	250dbf2812b23239a818f8fa5f463aefabe8d816004db1d5b81bdf175273076e	cat_dog_human@mail.ru	691572624913	data/unknown/unknown.png
256	cat_dog_bravo	b83d6522921453bceca8fb4b4196e4bdca6b2b3f8e5375c9eff1cab52835f931	cat_dog_bravo@mail.ru	229973077276	data/unknown/unknown.png
257	cat_dog_alfa	853e2764ba1b15b5ec702be2598ad618aed840899b4634c29dbfd6f5fbc8ff16	cat_dog_alfa@mail.ru	564300465316	data/unknown/unknown.png
258	cat_dog_delta	005e744ebad4428cf3048f468a0f785f6e3129e6dcf3a9ecdaf072bfb2ddbbdd	cat_dog_delta@mail.ru	763619241369	data/unknown/unknown.png
259	cat_dog_gamma	3a8cfad13e190a7d9c497cf4c921ea0dc6070278d6f843687fcaeb3bc4465ab1	cat_dog_gamma@mail.ru	85931850863	data/unknown/unknown.png
260	cat_bravo_city	cf69abfd2ccf943f6523e33abe4c2f2933d8ac7050ff17c2c306054b5331d866	cat_bravo_city@mail.ru	896597321232	data/unknown/unknown.png
261	cat_bravo_town	429efce3ea38d36aff80b37fc39229e31fa77e0d0ad4accda07799e13d37f53a	cat_bravo_town@mail.ru	474129255825	data/unknown/unknown.png
262	cat_bravo_food	6fed25f512639fb3d44566c1b1e2bfde8bc6d35b4006e9dc1f1742f41c75a9a8	cat_bravo_food@mail.ru	794236736137	data/unknown/unknown.png
263	cat_bravo_human	ecf215237b176803e6c0831a9d8134f0f122518c8081986b7d1630256c7b3d21	cat_bravo_human@mail.ru	406798494346	data/unknown/unknown.png
264	cat_bravo_dog	72a01459821bb3daa3281c93bdc37215fe9f5c73637c97046c58c511b1d2fdf8	cat_bravo_dog@mail.ru	510579323148	data/unknown/unknown.png
265	cat_bravo_alfa	8b52091d86935b894c89f7a63286e94d624e6cb33ad72a56be00b923b6d4181b	cat_bravo_alfa@mail.ru	889497491984	data/unknown/unknown.png
266	cat_bravo_delta	a37521d3059dd8d264f9c3ec2f81d9b9ecdbb9379fc16ae0a639e563bb511927	cat_bravo_delta@mail.ru	180200183701	data/unknown/unknown.png
267	cat_bravo_gamma	91b400b73ec7f7939f78911bba785a14859ff62044f8d781456cefd99f78b11b	cat_bravo_gamma@mail.ru	263450187564	data/unknown/unknown.png
268	cat_alfa_city	3ddf722604c6847270effa1bdc67b01ecb4d8f2d02fa4c54b03daa7579294465	cat_alfa_city@mail.ru	365678056154	data/unknown/unknown.png
269	cat_alfa_town	e33270cdfac8ab0a652b062ef8ebe987d99c127ab08933c0ec39ba2ef7ab6044	cat_alfa_town@mail.ru	427937108940	data/unknown/unknown.png
270	cat_alfa_food	4669ca21bb90457cb8c95a74ad0bf4d888f21a9663af0cee48b4e00275e2c805	cat_alfa_food@mail.ru	159838573453	data/unknown/unknown.png
271	cat_alfa_human	b683a829a7fd45c85f0654cc5c1864fc6513de4c46102a816901a00f56942499	cat_alfa_human@mail.ru	477396080525	data/unknown/unknown.png
272	cat_alfa_dog	2eadde94320db1a74376e4a689ff28737571746b7aa7988d38d83b5a8c16f019	cat_alfa_dog@mail.ru	188062963346	data/unknown/unknown.png
273	cat_alfa_bravo	676b77645511113cc93160b7205d7a0f8e023a32e89ae9de98a2402ea930fc8e	cat_alfa_bravo@mail.ru	239306879765	data/unknown/unknown.png
274	cat_alfa_delta	0977789013e91b417fab47c81bbc9a8bfbac986f9477ce39c0b4c99d856f6c3b	cat_alfa_delta@mail.ru	190066629615	data/unknown/unknown.png
275	cat_alfa_gamma	7c92553046913bc71e623ad4be0c312f494bfa26ee44d2b5eca14048be21011b	cat_alfa_gamma@mail.ru	172882317820	data/unknown/unknown.png
276	cat_delta_city	ee9568a2745cde292900218d72a8d9dbfdcc8d7fef73a9dd763b1bbee0a022cb	cat_delta_city@mail.ru	617880969323	data/unknown/unknown.png
277	cat_delta_town	6acd1e18077dcfbd6759c492f926756d6529073c608debef9782c4fd77d61006	cat_delta_town@mail.ru	277931238108	data/unknown/unknown.png
278	cat_delta_food	9f474c7d100f8b8e3d58994ecfa74bd67c26d63cf26cb7351cca6d4a7d4f6bf0	cat_delta_food@mail.ru	166136442689	data/unknown/unknown.png
279	cat_delta_human	534816d8aac5dbebf691d80fb4ef7aee27792e1b6a9e5f2e68b6cf597bef2a54	cat_delta_human@mail.ru	784817020767	data/unknown/unknown.png
280	cat_delta_dog	b0f9248055b8bb18505e29584def9bd49a3d08aa1e3ba9f44f7291d4f4b8dc3d	cat_delta_dog@mail.ru	362420655973	data/unknown/unknown.png
281	cat_delta_bravo	ce116800b8a018774d51993221e8b83ca4a5f19513de47b2b47a7262a01c7e07	cat_delta_bravo@mail.ru	512160090869	data/unknown/unknown.png
282	cat_delta_alfa	0042bedd57f8de73d4429de5ff5d6515622a8bee8f56869f307f3ec1e083f8f5	cat_delta_alfa@mail.ru	138745193806	data/unknown/unknown.png
283	cat_delta_gamma	fd1670146301ba21c858035c0735f74c7873f3ea364eef1dfc33f88aba309700	cat_delta_gamma@mail.ru	509319302561	data/unknown/unknown.png
284	cat_gamma_city	85072953d7561dcfadf6393f7af1c76e435072fc91388df5988a1370a597aa82	cat_gamma_city@mail.ru	744179098556	data/unknown/unknown.png
285	cat_gamma_town	27da06b9500fef21bcae69471eace3d6a3e140702f857f2ff50e9ced8df638c3	cat_gamma_town@mail.ru	342446530969	data/unknown/unknown.png
286	cat_gamma_food	95d80e518630bb09703cf1d4d7910f859d786e74d56bb4510a702c765045bc50	cat_gamma_food@mail.ru	294091158377	data/unknown/unknown.png
287	cat_gamma_human	5bae8caadc15c9b3d14403f5ef9d5a63656c590d701528de0af563e6e60a9493	cat_gamma_human@mail.ru	268573559497	data/unknown/unknown.png
288	cat_gamma_dog	df39d2eff1f0e7e5bf020c122cbe36030f05c692e03f681bf406fab307254829	cat_gamma_dog@mail.ru	87165828667	data/unknown/unknown.png
289	cat_gamma_bravo	07b9ae4a57282bcfbfa5991352aca3ee2985726dcbd3468b23e8a65822cdc0e9	cat_gamma_bravo@mail.ru	374443856314	data/unknown/unknown.png
290	cat_gamma_alfa	a39f61f9640aa63b663f0f8ab1aa587cd52d263d5397f40383b5a1239c7a3b44	cat_gamma_alfa@mail.ru	611172535248	data/unknown/unknown.png
291	cat_gamma_delta	0f5e241759cfbeefbb06cae086594de7cc16a05395e62d7ef839f83163563aba	cat_gamma_delta@mail.ru	344732239037	data/unknown/unknown.png
292	human_city_town	cb018c452ed70ce6b4fa22c9295e03310fb277990355ba15ba6a2c9533aba3bc	human_city_town@mail.ru	628648881818	data/unknown/unknown.png
293	human_city_food	5dd59ba05e6f7bb584031f3e88fc55e7ceeb3285b56c8d50c187dc314b076677	human_city_food@mail.ru	347796986802	data/unknown/unknown.png
294	human_city_cat	b4669b525ede90c5785c2a30d79969fd0e53064ff4cf3deed901c400e6babf62	human_city_cat@mail.ru	491355531251	data/unknown/unknown.png
295	human_city_dog	1d298789d36a49379f86d01e0de3790458d1e39004984859afd0550271971f17	human_city_dog@mail.ru	242160142006	data/unknown/unknown.png
296	human_city_bravo	c759956d8b353d0a58e6acb31f98031b455faf2d252bbff3d7c4a1d86dfdb315	human_city_bravo@mail.ru	361824626818	data/unknown/unknown.png
297	human_city_alfa	9abff07d303b15f181b86ddf696fae9c465c330a8051d91997124d27bd5385f4	human_city_alfa@mail.ru	277081987908	data/unknown/unknown.png
298	human_city_delta	18165f7968d101efe367457111cc7a6e21f439c166aace27e7a3875b46d8a361	human_city_delta@mail.ru	723078500734	data/unknown/unknown.png
299	human_city_gamma	ef12f9ab83796a4d00c4095723b5090bd140dc5c117aad84edb08725942a9198	human_city_gamma@mail.ru	747865470259	data/unknown/unknown.png
300	human_town_city	2d25a565ee5cc53b3ef05581c8ab104372cd0e005479afe86eecebc763296b63	human_town_city@mail.ru	140690714602	data/unknown/unknown.png
301	human_town_food	0dca084121968645384be8f2cc6c3b438d82f19a23b19b1697e96d4d6d7305e4	human_town_food@mail.ru	380899243827	data/unknown/unknown.png
302	human_town_cat	538ebb6f9d5b80315a3b0b29815702b1dbb15feea63fda59951642d32dd8d320	human_town_cat@mail.ru	672280474913	data/unknown/unknown.png
303	human_town_dog	dafe1df4ee2515ca72990a82e2b47d67a67dc815395135d3d8c3a3ce65344c80	human_town_dog@mail.ru	450830570667	data/unknown/unknown.png
304	human_town_bravo	ca950053c9ac59d33067aa6eda6140fefc99e9b39047e0d5737a46966c213f60	human_town_bravo@mail.ru	178603880366	data/unknown/unknown.png
305	human_town_alfa	e0badec68de810f0d7ea35c4f89d14c62275af0f429292c090151abbfa4a6b80	human_town_alfa@mail.ru	851409404420	data/unknown/unknown.png
306	human_town_delta	68576e60b17059dc89d1cfb54354913d0e313c6824361d82a260fdbf85213823	human_town_delta@mail.ru	356662441131	data/unknown/unknown.png
307	human_town_gamma	fef0b8d72ef15cfdec34a2f27e590d38f7ea9d515df33e127db8fbc4d343798d	human_town_gamma@mail.ru	271118592356	data/unknown/unknown.png
308	human_food_city	2f22b44453c044f1541f106016b92d60caeade98c22f95e4d5868fad5b1574f2	human_food_city@mail.ru	144033623473	data/unknown/unknown.png
309	human_food_town	ed3cdf5abaa12d866e91220c5611a8275fddfb72f47279a73ca4b4b515c46608	human_food_town@mail.ru	519959289210	data/unknown/unknown.png
310	human_food_cat	040b402821f264b6016bcfc919d7e4530b8fedee211d74083f02f86a940d571d	human_food_cat@mail.ru	172374499400	data/unknown/unknown.png
311	human_food_dog	c9a9dc8e9e8304a79cfb8b773a31627f929429ea7c948bca3296534baafd7730	human_food_dog@mail.ru	499293067768	data/unknown/unknown.png
312	human_food_bravo	75bd3468e56720ac91c3cab9b5ac9a617c4822a1688371fa39e8a679a9b4b285	human_food_bravo@mail.ru	834773269895	data/unknown/unknown.png
313	human_food_alfa	e312d0d8ddf72aa699d353b52c0357065b343ea5df1aeea21e222a5a06eb287e	human_food_alfa@mail.ru	563962241832	data/unknown/unknown.png
314	human_food_delta	4ef2ce63e5b2ee82910211bdc04d1cf6a62b07b3b1883b30e2e2f0d79189d992	human_food_delta@mail.ru	496608301628	data/unknown/unknown.png
315	human_food_gamma	4f1d264a0493941b518b0e870e98f556409daf02aecddea505028e996373694e	human_food_gamma@mail.ru	827643212208	data/unknown/unknown.png
316	human_cat_city	0b8348a6d0ffbddac4a25232ca7d69a711aead6c8ec773c7ea8ec156f029b5f0	human_cat_city@mail.ru	153764211663	data/unknown/unknown.png
317	human_cat_town	5e7e042957e028eecd6c02e918a26bdf9e8ffe803a640984e713ee33b3ee2e86	human_cat_town@mail.ru	518076686360	data/unknown/unknown.png
318	human_cat_food	4bfe8680854674871fdc98fb8885a2f38d4eaafdb07f9a4e28add5ba26ed7684	human_cat_food@mail.ru	182057843889	data/unknown/unknown.png
319	human_cat_dog	8a1668945d0b03602df1a01c6f4ece2b23d0058f97bad3d1adf100941e5ceb77	human_cat_dog@mail.ru	477139981207	data/unknown/unknown.png
320	human_cat_bravo	6780959c2e504b0d0d392a92bf04ea4fa3357f942f2762b2d4fbd00c138744da	human_cat_bravo@mail.ru	706641034488	data/unknown/unknown.png
321	human_cat_alfa	5b57b06b2172057ac05f0894c9251dda0e1e6381cbbf3bf2702ad818c4b07610	human_cat_alfa@mail.ru	380274238774	data/unknown/unknown.png
322	human_cat_delta	2d84618f2e2eeae5ad98dcd06e742365043f2498fe34c248d04b3a565dca5bf9	human_cat_delta@mail.ru	673964238973	data/unknown/unknown.png
323	human_cat_gamma	c707fb8dadf79213ca4d6be4423431d55273792458d0762b7820766c8c65255f	human_cat_gamma@mail.ru	864951925122	data/unknown/unknown.png
324	human_dog_city	155b59be6bc68a0aeee2e0b88e9befd6d9f2e3208a1b1fdd8ab2fdc86575562d	human_dog_city@mail.ru	536958837853	data/unknown/unknown.png
325	human_dog_town	93cbe982ed8b4c1efffb36a4dfb596b473a3f13dec59cc21d97f09422a65e99d	human_dog_town@mail.ru	171510555142	data/unknown/unknown.png
326	human_dog_food	f9b9df4bc078818535f8a2cd9b00b2f77bffc07977eea5b5983a72737e3de332	human_dog_food@mail.ru	496358143379	data/unknown/unknown.png
327	human_dog_cat	0f70643329a17bedddfd8b3bba6a4f5a9c7e564c3eed4a258982141b73b24814	human_dog_cat@mail.ru	875181115770	data/unknown/unknown.png
328	human_dog_bravo	6551296983fe60d3d0c819a011535ad36f4c3bbfde442bc4ecef251c66ba18bc	human_dog_bravo@mail.ru	112490837508	data/unknown/unknown.png
329	human_dog_alfa	62ecf409847aaf78c34433f78e3e085ad971c5813fa74dc276e22711d12799c1	human_dog_alfa@mail.ru	645219716864	data/unknown/unknown.png
330	human_dog_delta	a7af808c1fac52cd0b7ea7d4ed245e663433fe76c299cd5513382348cd95f76d	human_dog_delta@mail.ru	610442175522	data/unknown/unknown.png
331	human_dog_gamma	1e03d88d2a65f8c0a9b8b27268a780cc7e1f640d899ac87ba673086f0d0e6361	human_dog_gamma@mail.ru	236689395758	data/unknown/unknown.png
332	human_bravo_city	f92092b7f03533adf75303c1e07f157800700345e4585830d91876eb57a1ddfe	human_bravo_city@mail.ru	139918284572	data/unknown/unknown.png
333	human_bravo_town	9f3e5e37ea2652190d222fdca4fa7b55f73d0ebffc9bf91613731638e099b8e7	human_bravo_town@mail.ru	614563463608	data/unknown/unknown.png
334	human_bravo_food	042aedc0304c3262e9294be0ebab7426b49aaf487ebd0494613b928621349dfc	human_bravo_food@mail.ru	836171966986	data/unknown/unknown.png
335	human_bravo_cat	6a3e6ac904f92514391e5d9270c9751a65a01729a4f320f5263e07611405b1ed	human_bravo_cat@mail.ru	593002898658	data/unknown/unknown.png
336	human_bravo_dog	d1e1ca9b4ba36156c1bf0597abe74922efecc3cad8a61f5063de65d3f582b7e8	human_bravo_dog@mail.ru	404022593156	data/unknown/unknown.png
337	human_bravo_alfa	18aaa3652c12e9def1ce7d778e7243f6f29e3ed53a5565c1d2b6e2c85ec197f7	human_bravo_alfa@mail.ru	428297845761	data/unknown/unknown.png
338	human_bravo_delta	c6844ffa581b557a6c4532fe26724a189548b170bcddc4c1a9bf13588854fef6	human_bravo_delta@mail.ru	512455112095	data/unknown/unknown.png
339	human_bravo_gamma	2519f22c7c2fda721235962261d4d0651d7568df4f09bf8e6ed3e01433b415cf	human_bravo_gamma@mail.ru	773383154423	data/unknown/unknown.png
340	human_alfa_city	d1fc443af33e611ad2555ea06fce23be9f8e1ddd8f9858b17a58c1524598131d	human_alfa_city@mail.ru	494584470480	data/unknown/unknown.png
341	human_alfa_town	8f2c6eb09ad3fa8f47b2564247e9629161c0c4adf9899af53756a1d3ddbee72b	human_alfa_town@mail.ru	172790363034	data/unknown/unknown.png
342	human_alfa_food	727611a997096d0afbb30253712bd61f3cb580bacbb80a9da539d006144aa79c	human_alfa_food@mail.ru	393590453553	data/unknown/unknown.png
343	human_alfa_cat	e4de3ebaa4fc800a74b419ee4fb34985746598de6e2b6ab6a4d0812190582ef6	human_alfa_cat@mail.ru	160501776434	data/unknown/unknown.png
344	human_alfa_dog	3284abe64d2716c81c3785d76c657cd16019ed9edba24cf571cda7f08f78f6bf	human_alfa_dog@mail.ru	329914671985	data/unknown/unknown.png
345	human_alfa_bravo	edf67d417b47435e54045f72dd760e69053667f6261003503d1e4cfccfd18e2c	human_alfa_bravo@mail.ru	87372694526	data/unknown/unknown.png
346	human_alfa_delta	803fef2df0655b057717a2bae360b5bc29279b82d21fee6835c91a321e1867ac	human_alfa_delta@mail.ru	440427539453	data/unknown/unknown.png
347	human_alfa_gamma	14e519a8682c7be78da165c82cf4e9391f11ae472adc47570ad77f5eb35d3f46	human_alfa_gamma@mail.ru	651626795455	data/unknown/unknown.png
348	human_delta_city	b8e3013b676c197022f3b05771407b07a99847979ea67bf24b281f752afbf9e8	human_delta_city@mail.ru	712883059410	data/unknown/unknown.png
349	human_delta_town	0abef2c5fc9a5d96b104d9f80c563e740589ec05b493376e28cc5e03006dab64	human_delta_town@mail.ru	227267686817	data/unknown/unknown.png
350	human_delta_food	6e3505ecb6212f144d716f3f0f4f045ba92ba2ccdda645d0a35ade6498c31500	human_delta_food@mail.ru	161824667586	data/unknown/unknown.png
351	human_delta_cat	95b3fc6c20cdeb0ddbd7e68d6b6df81d0cad023007a5600a3993b207815fc03b	human_delta_cat@mail.ru	179561557701	data/unknown/unknown.png
352	human_delta_dog	62a36cb20c8eea506eeef33de7249ffc01063e37f4326e509ba1d16f2d1278d9	human_delta_dog@mail.ru	128407070766	data/unknown/unknown.png
353	human_delta_bravo	52a3d5cf2f217922044ca97bdaf8dc57c8bb630e746afdd0de2a378aba9a4fda	human_delta_bravo@mail.ru	781594096755	data/unknown/unknown.png
354	human_delta_alfa	1ed2f7cbaa5cdabccb3badd821d7f95b147f279c0d612841d9884cf2bd8d7617	human_delta_alfa@mail.ru	625602577743	data/unknown/unknown.png
355	human_delta_gamma	2b28da8760312a883467faf10ccc5a02e61ea15ae7866c7852b92ac8ab081261	human_delta_gamma@mail.ru	668522499920	data/unknown/unknown.png
356	human_gamma_city	885376427f2eb46c91a1de7996fd9e942e67c7aadd4df4a54df9e232ea35f872	human_gamma_city@mail.ru	485016227720	data/unknown/unknown.png
357	human_gamma_town	1fff16d7359eeba3083624c859e5bf68aa6f99eb1125fbab7b3543b073d5b456	human_gamma_town@mail.ru	774892502298	data/unknown/unknown.png
358	human_gamma_food	f5b6dc7a022f60f0a0d7c076f1e534178f025b46b6c52f8b4cf7e935f237b095	human_gamma_food@mail.ru	561628997419	data/unknown/unknown.png
359	human_gamma_cat	350a99083d766f0e18a9c82f6fc3f0f38b0a3f8351e0b7e656ecd0125c6e60a7	human_gamma_cat@mail.ru	872154326115	data/unknown/unknown.png
360	human_gamma_dog	1b4f58dfcc9199713765670896f9db2dce4c9a8919d5a4f1f767ff41086f4dcc	human_gamma_dog@mail.ru	118197740485	data/unknown/unknown.png
361	human_gamma_bravo	d39e6f6c1961216c722713973f824d6e3d92e2c99679c514251cfb834325e665	human_gamma_bravo@mail.ru	856978904979	data/unknown/unknown.png
362	human_gamma_alfa	f6f1eb008071031eb326cb0e48cf4806f5d1ef891d32e9414b486bda49c6c238	human_gamma_alfa@mail.ru	80435947096	data/unknown/unknown.png
363	human_gamma_delta	cc828418ff602d18a1ace99bcbbb7dd5a6e4ab863eb66c33825f7a1447969ec4	human_gamma_delta@mail.ru	592231185520	data/unknown/unknown.png
364	dog_city_town	3d730dbaf5b182a1a8b4de273550e816ccfe180523699bbab51719af2a2e4624	dog_city_town@mail.ru	729471570189	data/unknown/unknown.png
365	dog_city_food	02ac6bdc72bae3ae2409ff1fb177c64d4e9699bbd971ff169d34a1baf5b40a13	dog_city_food@mail.ru	374515926955	data/unknown/unknown.png
366	dog_city_cat	81120dc38ba6a7a4146543a63e7b325a848f3790f7c789f05cf9d0dc98174d78	dog_city_cat@mail.ru	212955185703	data/unknown/unknown.png
367	dog_city_human	57ac18871c79f631676812978f729700eeeb931f7d3f4e86580a7ccdea396dbc	dog_city_human@mail.ru	841541832592	data/unknown/unknown.png
368	dog_city_bravo	f471b50be3ef5b9fb66d50b2ce8c5dcf5c55680f3633ed41361729bd991b0922	dog_city_bravo@mail.ru	850943509027	data/unknown/unknown.png
369	dog_city_alfa	f76475240ad9bd88be6f2d79cd8a90b12124760ac0949dad2c101aeaa50fbeb9	dog_city_alfa@mail.ru	185112542510	data/unknown/unknown.png
370	dog_city_delta	8331a3897e4622dd1c610b7c154c3de564e6dae2038b0119120804b89f203948	dog_city_delta@mail.ru	825438088001	data/unknown/unknown.png
371	dog_city_gamma	e20b371b379fb6cc308d96e0be26a386413cc2c080aa6c974fdeca33a921020c	dog_city_gamma@mail.ru	375713705044	data/unknown/unknown.png
372	dog_town_city	1c42aac4c7144c65074f3c1f4362070a0f0f5c76948b5a77c87421026bb06506	dog_town_city@mail.ru	180468321411	data/unknown/unknown.png
373	dog_town_food	81f659e194d3bb7942680e60e480ba80ae7265e902ab0524c503cb7a96c2deb9	dog_town_food@mail.ru	471903718442	data/unknown/unknown.png
374	dog_town_cat	8fd0d8d84fcafd2654e438e2d9f16e236a27a5483a4fe368f7b1733f0207102f	dog_town_cat@mail.ru	486743744397	data/unknown/unknown.png
375	dog_town_human	c1a75bec10029a311cf683c1b177c3f8497c36ff97d7d96158585213706689b5	dog_town_human@mail.ru	763095783673	data/unknown/unknown.png
376	dog_town_bravo	3dbd42fad10c6e4cce072bd02b09661175df2f461df50c572a0a8f2e2773c332	dog_town_bravo@mail.ru	623158004134	data/unknown/unknown.png
377	dog_town_alfa	6f4d4d310ebdbf0ec398ded65e5d445b2663abffb76376c1b336725788aef257	dog_town_alfa@mail.ru	232997442548	data/unknown/unknown.png
378	dog_town_delta	be60c72ac8ab470c2af6f4522c9beddb1ee9d5e017b893c613ffac289b0a9f74	dog_town_delta@mail.ru	622328494752	data/unknown/unknown.png
379	dog_town_gamma	4eca3e7b8db16bee816e55f6856a75eeea7e1169dd43e354dfba2018a15f3b64	dog_town_gamma@mail.ru	803846608779	data/unknown/unknown.png
380	dog_food_city	16ea46fef2e80e2dcb32395cabd1db8cf369d99a18ce684879615d4a93ea6075	dog_food_city@mail.ru	649140173294	data/unknown/unknown.png
381	dog_food_town	b4e597fc180f7e958a396f468e607037a612006f4d9f4b175b24961966d15db1	dog_food_town@mail.ru	839342195292	data/unknown/unknown.png
382	dog_food_cat	9ae89154842100742c63af4ef5925de634ce1487793e656451d18ec95ce1473a	dog_food_cat@mail.ru	100489620953	data/unknown/unknown.png
383	dog_food_human	7ace576520ba3d5a93aba8f842684cb8df42ad1c831190e1276a5bd5b9833829	dog_food_human@mail.ru	384362141022	data/unknown/unknown.png
384	dog_food_bravo	2a38d8fb93c4c8c663f15b78ab5b53bf9144b6b348a4e564e0cfbd023ecd186c	dog_food_bravo@mail.ru	563926556712	data/unknown/unknown.png
385	dog_food_alfa	d68662d3bf21960f7ec336890bfe674a15e4770251e80c1e07b255990d227822	dog_food_alfa@mail.ru	183367950723	data/unknown/unknown.png
386	dog_food_delta	20a06dc6955e0b7575b1356b31bdddf05b7af1063be08bbbe7c02579f4c4bf64	dog_food_delta@mail.ru	148175481434	data/unknown/unknown.png
387	dog_food_gamma	7b9e8e79874e10f9d46d1387a97938df0ba9743e1a2fec46f8987beea732920c	dog_food_gamma@mail.ru	120711510521	data/unknown/unknown.png
388	dog_cat_city	cea1330a64d658c93e3fe11f73c5e22a43686c1d9b0366c671af54ede8f6f746	dog_cat_city@mail.ru	695233219775	data/unknown/unknown.png
389	dog_cat_town	f8d4880c19c9845acd5f142f79bcd3f05523f4a4b5df1ea83b59a9c773dec1d7	dog_cat_town@mail.ru	874131606738	data/unknown/unknown.png
390	dog_cat_food	d84e64f5b4b8e3325aef9f102486f2a1cfa53dde0b990c63bd87f1ded8bc6077	dog_cat_food@mail.ru	383363750982	data/unknown/unknown.png
391	dog_cat_human	511defa248cf4302964c77bfe68ca8e18b955016291b88525235bc42a15a0f77	dog_cat_human@mail.ru	885200273472	data/unknown/unknown.png
392	dog_cat_bravo	f8786b131aa67324728eeb637e10092170b2dd32c1afd999e18bba08e10d063e	dog_cat_bravo@mail.ru	513595859130	data/unknown/unknown.png
393	dog_cat_alfa	67aecd16338edd0d54712a318f7233d9d4035378fa33e33366e0d0aa64f96be2	dog_cat_alfa@mail.ru	336579877685	data/unknown/unknown.png
394	dog_cat_delta	f397b2f697006fdb023e4bd9c50c51df7a7dd35825ce63a0c038f90f4fc312d8	dog_cat_delta@mail.ru	673256360887	data/unknown/unknown.png
395	dog_cat_gamma	6d4acc0eb35dd428698d61517db84c7528430f8f39ea51ef2118e75eb6c36bd3	dog_cat_gamma@mail.ru	471813493456	data/unknown/unknown.png
396	dog_human_city	67f7f37f7402793dbc200a6f403044a27c139362a98f6b19fb3b31a913c9e279	dog_human_city@mail.ru	635859945458	data/unknown/unknown.png
397	dog_human_town	cdd9e1d0c8d642bd22ea1d816b276e4295609af0bd8a09571556521bd6cfcd9f	dog_human_town@mail.ru	248998259722	data/unknown/unknown.png
398	dog_human_food	93de46fe90e6f7df8f7c9a52ebf24b2e6c69adbbbe0b5d156f7966b2cfedff5d	dog_human_food@mail.ru	203430568262	data/unknown/unknown.png
399	dog_human_cat	0ed1bb4d12c863385ad18f050e6b5ccc642b7cd731291d376cb53508421d5d60	dog_human_cat@mail.ru	366605258022	data/unknown/unknown.png
400	dog_human_bravo	62f05b02901484c06b054f429c48b365c7da1cf4d611bd409340c55f49bd07a6	dog_human_bravo@mail.ru	857544222410	data/unknown/unknown.png
401	dog_human_alfa	07ea8db76bb2c08f4db38425882d1393c05cf88e5e191c2cba1fdc54e593f6b2	dog_human_alfa@mail.ru	419784800911	data/unknown/unknown.png
402	dog_human_delta	4e1c2436ac69ac35301f7749c7f6b23122f627ad6e816d9910e2a8d57f0b2516	dog_human_delta@mail.ru	556271192405	data/unknown/unknown.png
403	dog_human_gamma	b6f6ea342bf7ea05dbe45708c8505fa59615afe1bf745cf5be08f9e7788d3970	dog_human_gamma@mail.ru	394726233008	data/unknown/unknown.png
404	dog_bravo_city	cba8bf142e55dfeec5f2e2855324a330a7ac43015de91799bb875df488f4e750	dog_bravo_city@mail.ru	118611120157	data/unknown/unknown.png
405	dog_bravo_town	7f9481b7cc683ff0bfaca2e6eb468517867431245bc27bd8a2d74bee302e76bf	dog_bravo_town@mail.ru	484108013488	data/unknown/unknown.png
406	dog_bravo_food	4ec738dd0fbe852d116d083fb7b6d597f97a2eee4cad79627129b866773e788c	dog_bravo_food@mail.ru	640557399171	data/unknown/unknown.png
407	dog_bravo_cat	cd2d1e067be360c9c2bfb7daba5b9285c983c628663a139beabd8f80e75792d3	dog_bravo_cat@mail.ru	726633599587	data/unknown/unknown.png
408	dog_bravo_human	b739b3f29ef4cf333794d9d557ac9e1e3365beac13d9d99d3d2e9d9c4aa3fbe2	dog_bravo_human@mail.ru	774735470756	data/unknown/unknown.png
409	dog_bravo_alfa	6b02489db6032c8411d0c5fc45a89848e472624b30908cb1c8fa72cca7545263	dog_bravo_alfa@mail.ru	100575346729	data/unknown/unknown.png
410	dog_bravo_delta	67fd25f2e36e6cdccc49cc61d34f2460f1be4587e4204e10348343af893567f3	dog_bravo_delta@mail.ru	247302411503	data/unknown/unknown.png
411	dog_bravo_gamma	471f25b65c9b5d6becf6f002bb1f8016ed7613dcd0369262e130da821f6fac82	dog_bravo_gamma@mail.ru	688218018537	data/unknown/unknown.png
412	dog_alfa_city	6d5ca4251e7750e5133af8f1da581e233b28d9606aaef8b13094bb0d2d59e2a3	dog_alfa_city@mail.ru	650518566281	data/unknown/unknown.png
413	dog_alfa_town	b49484d4d52a4fe57d494bdeda761f6387927fe82b024b34d676c7c4640ba007	dog_alfa_town@mail.ru	823777397759	data/unknown/unknown.png
414	dog_alfa_food	a05c8e2a4a6a499a2398565c093f7f82ccfbac63d845ce85d900bbd04b817092	dog_alfa_food@mail.ru	287155723696	data/unknown/unknown.png
415	dog_alfa_cat	eabfe7536cef52d5a5a33b26e87841a20db3948a0fb5bf407bf93b6cce644268	dog_alfa_cat@mail.ru	827031405535	data/unknown/unknown.png
416	dog_alfa_human	13350bf7765cc90e62585aba8e9d1c8aa1cca7fe9093e2d5a779807c7ff6ca7a	dog_alfa_human@mail.ru	147073679891	data/unknown/unknown.png
417	dog_alfa_bravo	52ca048184d585e69ab9d0be8878b9cbfc7b7450078c23363ed7019a072359e7	dog_alfa_bravo@mail.ru	662217239606	data/unknown/unknown.png
418	dog_alfa_delta	a65d476562df2ded3c6cc6948ec1697351c75216bcf151978e3487ecb864693f	dog_alfa_delta@mail.ru	881423701985	data/unknown/unknown.png
419	dog_alfa_gamma	fb6d2efd0f130d5517154aa5ea2d8972327a7db22ab09588bb3e3682dc104734	dog_alfa_gamma@mail.ru	753930046357	data/unknown/unknown.png
420	dog_delta_city	1e00d891fd4337838be1e03c2786c600bb21235bbfc0247d2a6914879aab4eb7	dog_delta_city@mail.ru	341221790490	data/unknown/unknown.png
421	dog_delta_town	8565eb66073a31645b2e5641efc69b32be6cf383a4b5207eba4df5bba28f3037	dog_delta_town@mail.ru	635539214028	data/unknown/unknown.png
422	dog_delta_food	061a8d8252ef5521c85ba48f45015b93365f316d6d3da2e46717531488c4919e	dog_delta_food@mail.ru	602359455749	data/unknown/unknown.png
423	dog_delta_cat	fa224d70f31a4f104caca7754f052547df9dcd37941edd3a6ffd49c66f04e5c6	dog_delta_cat@mail.ru	867935892968	data/unknown/unknown.png
424	dog_delta_human	cf28bdb61fcc6de700f79a8884f69690a897a71546d0cbc3d96e13ae7e60d12d	dog_delta_human@mail.ru	179720232474	data/unknown/unknown.png
425	dog_delta_bravo	9c1e561b7065a6e1c382bbc96b122a37c49c69b0d3f1940a969f68e4b7630032	dog_delta_bravo@mail.ru	696400024025	data/unknown/unknown.png
426	dog_delta_alfa	c9734ec8fd108a74c157366c191bb1ccb5cd11cc6ad0f6e0f72686fcd3257342	dog_delta_alfa@mail.ru	387891823790	data/unknown/unknown.png
427	dog_delta_gamma	69cbc3aa1c127f0a3ae616e685b555d5c9b745eec5f479cd0cf5ce4969807e27	dog_delta_gamma@mail.ru	438305896664	data/unknown/unknown.png
428	dog_gamma_city	28ffd0c9c177342c98d540178cbed8925c41e14f4e86211416b556093d990097	dog_gamma_city@mail.ru	614401061233	data/unknown/unknown.png
429	dog_gamma_town	2fc6139b359bf893b9b90cdecdeb2cc7aba48662c05657aeeebca2fa45bdf903	dog_gamma_town@mail.ru	555556415038	data/unknown/unknown.png
430	dog_gamma_food	b5f82e27d7e7ba4c6d023f5e0fb60feafaac2cc9a8827d8162881172d06cdbfc	dog_gamma_food@mail.ru	759942011180	data/unknown/unknown.png
431	dog_gamma_cat	eb3a9ee89c44070d0f026b1d25d9f63d48264c9b5d852d3653c929eed118e93a	dog_gamma_cat@mail.ru	710452847332	data/unknown/unknown.png
432	dog_gamma_human	26af52ea3bee71b3a8f29b796d0d3efe78ae0aa37caf8f8b5943dc719e8593de	dog_gamma_human@mail.ru	395940440930	data/unknown/unknown.png
433	dog_gamma_bravo	55f4236db51299ef88383464145ad6d8beb6e14ecc8e0cc121fde86246a86a3c	dog_gamma_bravo@mail.ru	339064021606	data/unknown/unknown.png
434	dog_gamma_alfa	0d925a9bfb71a4061c1b9b6280b6e4c2f7f5b98f50f524aefb5619a905d2b5ef	dog_gamma_alfa@mail.ru	464450289869	data/unknown/unknown.png
435	dog_gamma_delta	bdb5db26be7d67efac0b94830dd03c87a97bf3bcb1774d9ea7c6040f9fc083c8	dog_gamma_delta@mail.ru	270113178343	data/unknown/unknown.png
436	bravo_city_town	3fa11552a3b39debf7c436c28ae6baf8838f47feb4ff732e7052b7c921c398d2	bravo_city_town@mail.ru	852788989733	data/unknown/unknown.png
437	bravo_city_food	2658db51ca61de036ef37a5ba58f8d368e7181ecbb5feb414b29b386c3fc1ae9	bravo_city_food@mail.ru	389971020637	data/unknown/unknown.png
438	bravo_city_cat	9ebee1014c0a29c1fbf0084e0680d9e249dee08206aeebb971ad6fac75ef7c5e	bravo_city_cat@mail.ru	853919353558	data/unknown/unknown.png
439	bravo_city_human	6b013d20c0917408b141d3b7670a79f792d4785c74380004fb5af67d5cdd49ad	bravo_city_human@mail.ru	311454608652	data/unknown/unknown.png
440	bravo_city_dog	11068652c402d684c297074c8a7eb3ce8d11b1e1bf686dc4877330c7ade4a915	bravo_city_dog@mail.ru	325579883240	data/unknown/unknown.png
441	bravo_city_alfa	5ac7e4e0db845234a1c803fce5f38fd3ee5cf147efaf5d2e9b88c5e31ed9dde6	bravo_city_alfa@mail.ru	480321668819	data/unknown/unknown.png
442	bravo_city_delta	7be2a0a3301e88b0926e179d587db65d9558973bfefb6cadeea5f323be885c5b	bravo_city_delta@mail.ru	838326279225	data/unknown/unknown.png
443	bravo_city_gamma	0f3634cb64c2fe71384c4f870f1df07a67a2962a278318bced514616d9793e72	bravo_city_gamma@mail.ru	762087988702	data/unknown/unknown.png
444	bravo_town_city	a255245191bb8906c240401c56b84640f57e5660541e63d1f85f8b289c2286a3	bravo_town_city@mail.ru	568717354741	data/unknown/unknown.png
445	bravo_town_food	7138489c5d80931c8418b9b82b0072350dc8cc4fcb7adfa25dd9f53aa2214ac9	bravo_town_food@mail.ru	182757645989	data/unknown/unknown.png
446	bravo_town_cat	e1a58c906d42913e5f680bb2b213322e716cd89f01fbfe2abff7d3f86ff279c2	bravo_town_cat@mail.ru	854321263375	data/unknown/unknown.png
447	bravo_town_human	be089e464fc53020b3e0d5fcf7a68043839aff65df9516d59e9eb10fd022c855	bravo_town_human@mail.ru	650610934443	data/unknown/unknown.png
448	bravo_town_dog	ddd77e1d44485807a84a39b51c7dd9101121ef898d21ecc3908557ca39c98b52	bravo_town_dog@mail.ru	582581812690	data/unknown/unknown.png
449	bravo_town_alfa	bbd32747a3f86c85718fbf24778653c2cee1c7e9ccb2935aeead4237b6ce3261	bravo_town_alfa@mail.ru	749007890265	data/unknown/unknown.png
450	bravo_town_delta	c6b9717936e4f810781821d1f9515f0798d8b93d8973308fcf1f8beb57452af7	bravo_town_delta@mail.ru	94895710004	data/unknown/unknown.png
451	bravo_town_gamma	26bb07d8888f611d1f8dfef902d0312449f65b5c7cde6c2d30f136c35cadd397	bravo_town_gamma@mail.ru	800466547780	data/unknown/unknown.png
452	bravo_food_city	f3f2213ba46e1ee3588d01c352277c44625749b10e5f4b3e91b790ebbecfd65c	bravo_food_city@mail.ru	519835225180	data/unknown/unknown.png
453	bravo_food_town	4c8cd3418c4624bba0d6f7941224f9f24096cb8eab801565a437285c0a969e23	bravo_food_town@mail.ru	341622891638	data/unknown/unknown.png
454	bravo_food_cat	1f39621a40645d6349038cf333ccce38135646be64300a3d605cc7d0c43de57b	bravo_food_cat@mail.ru	695719033310	data/unknown/unknown.png
455	bravo_food_human	698295bec6f9e6a45c1d8fe706b6c432c367eee8ed4cc6360303e6c49e37020a	bravo_food_human@mail.ru	800823376641	data/unknown/unknown.png
456	bravo_food_dog	05589c184140901ce5ab087c6904f67b6aee0dcc35c562195f1c1b6d9ccce803	bravo_food_dog@mail.ru	316406054344	data/unknown/unknown.png
457	bravo_food_alfa	8c45842a3f1e03d4e5af3ea711c8edf242cbcbd5afda9d06522153ee416bc76f	bravo_food_alfa@mail.ru	270835194514	data/unknown/unknown.png
458	bravo_food_delta	b224c700d82fc32f7d50a581b4234e4334b9535bfd0715af2620eb83d72807d2	bravo_food_delta@mail.ru	752932815328	data/unknown/unknown.png
459	bravo_food_gamma	3832b8e922765ed94a283fb6bec070490b0cee98fcd41e225b82f25cedd29772	bravo_food_gamma@mail.ru	97781658654	data/unknown/unknown.png
460	bravo_cat_city	4209f011428e54a10261777499f1c9f6bd4c964a1763117afdf9b07790b58722	bravo_cat_city@mail.ru	567006270809	data/unknown/unknown.png
461	bravo_cat_town	67dbe775fceebb2df5ac208a5adfc6f23878df06ab5fe62f6877a40d9bf90c91	bravo_cat_town@mail.ru	841698874789	data/unknown/unknown.png
462	bravo_cat_food	92dbc9ade370d54f32ced09892474fb1a304f437f67176d2aefb425877ecb37d	bravo_cat_food@mail.ru	876636366213	data/unknown/unknown.png
463	bravo_cat_human	51ac1ee0bf24d2abe08c47bcd4ff113743472cae259002eec25b911976a3b562	bravo_cat_human@mail.ru	494355243462	data/unknown/unknown.png
464	bravo_cat_dog	ea04ed721253ca5a05c28a77fdd900b5eb748d380d0a7f79a649e32325a91580	bravo_cat_dog@mail.ru	840813046677	data/unknown/unknown.png
465	bravo_cat_alfa	db0c862142e3713cf4b381c3351a77fad3705d96e41bc71b6dfcb0a59f328358	bravo_cat_alfa@mail.ru	191166315172	data/unknown/unknown.png
466	bravo_cat_delta	fa90e476b9f8f08ffdffe7fb82330ba25190a733fdcf2c656522bf98806369cc	bravo_cat_delta@mail.ru	637952571624	data/unknown/unknown.png
467	bravo_cat_gamma	579dc0f178cc945d412a9878c9682a79e5b8ab654d28316dde815af84274da62	bravo_cat_gamma@mail.ru	339604087408	data/unknown/unknown.png
468	bravo_human_city	12d9af3a4da46dbc457a9deb1e2838bdce522c82eee2073759eca2a15ae40eec	bravo_human_city@mail.ru	226093289077	data/unknown/unknown.png
469	bravo_human_town	aca8d73941f62161ccc19587c4ac60af3075aab099ad05ddb692833b2f6d4d69	bravo_human_town@mail.ru	260710918725	data/unknown/unknown.png
470	bravo_human_food	99b7100b2a76fcd74c1c71f29e53ab3327e248584827c36fa44c758544d898bd	bravo_human_food@mail.ru	380700413078	data/unknown/unknown.png
471	bravo_human_cat	8e2b4612bb332f29de2cec870ce3bcab165cecdc440aff4ff2af148a50429686	bravo_human_cat@mail.ru	461270109420	data/unknown/unknown.png
472	bravo_human_dog	90e37035c3812f05816491a7603ccf292492a25a07329607b536494e33a609a7	bravo_human_dog@mail.ru	465266881808	data/unknown/unknown.png
473	bravo_human_alfa	b582927c8cbb011207afc992d2864cd67351194f2603755365b9ddaf29195bb5	bravo_human_alfa@mail.ru	744802026781	data/unknown/unknown.png
474	bravo_human_delta	0364a30a1e5eeae06472f2144d04761faae540ab599e294d3885da3b0a2f597e	bravo_human_delta@mail.ru	348326014835	data/unknown/unknown.png
475	bravo_human_gamma	a21899edf227380384acdfeed9b2ac4c960ab6f2871adeafc450f50401127f6d	bravo_human_gamma@mail.ru	511081990572	data/unknown/unknown.png
476	bravo_dog_city	5dccdd3d64aab40d5138f4c796a63c47d9967b11495d6534a10c075071826f2f	bravo_dog_city@mail.ru	285537704627	data/unknown/unknown.png
477	bravo_dog_town	076d60e41f7047105f3171df2b81f45dadc0da3bb12f6a68296fac1149cd643c	bravo_dog_town@mail.ru	617911710108	data/unknown/unknown.png
478	bravo_dog_food	a69943c4939ae7feef50fa94beb17f2b3c87511dacf97758e5d0b95266c1f037	bravo_dog_food@mail.ru	499328717072	data/unknown/unknown.png
479	bravo_dog_cat	9e7b4d416413489ca3beb579347446be107579a664e3996b9655234aed1a8afc	bravo_dog_cat@mail.ru	152262878210	data/unknown/unknown.png
480	bravo_dog_human	9f0bd591770c1dd106b376354e0f2abe412688c7945504d47a5ce5097455ad30	bravo_dog_human@mail.ru	755859919949	data/unknown/unknown.png
481	bravo_dog_alfa	efebb100a41dbda9cc6aa87c746156297e1e6a88aa9aa778b0acce7e584a8f3f	bravo_dog_alfa@mail.ru	695624014127	data/unknown/unknown.png
482	bravo_dog_delta	d895130c63a4ce85d5a84b335bd0210cdd6b1aa5984ef68ac1c35d6c0364c8c7	bravo_dog_delta@mail.ru	818912064888	data/unknown/unknown.png
483	bravo_dog_gamma	f39ccbf50d7a144f0ed3e998a4d6d15e46ff6868bb309b591f53abf1149f1860	bravo_dog_gamma@mail.ru	531602969327	data/unknown/unknown.png
484	bravo_alfa_city	0122e273156321ded9922cf935c46dd3fb6f45ceba4cc2ba974d8cb4e4efd7c4	bravo_alfa_city@mail.ru	674775183591	data/unknown/unknown.png
485	bravo_alfa_town	f68f920e56c1046fe581f1206e3d81a9ae76dc72636e9fcef4cd48177711062b	bravo_alfa_town@mail.ru	374453469371	data/unknown/unknown.png
486	bravo_alfa_food	a0aa3f92b21ae8f20aa9bac3ecdfc83273f40a92c793abd3ad39ab2599c4a9b7	bravo_alfa_food@mail.ru	829868341572	data/unknown/unknown.png
487	bravo_alfa_cat	0c90e1eb2de0412d9d9af20d5be0bbd666d49a0d2d064a96df65de3719c4c1b8	bravo_alfa_cat@mail.ru	714079518972	data/unknown/unknown.png
488	bravo_alfa_human	7101f74b4d080d5d5f21c73707a3af429bec3e4aeb3a0eb5efb73cbc9a07ca20	bravo_alfa_human@mail.ru	426865239489	data/unknown/unknown.png
489	bravo_alfa_dog	debeee8f2d4b2d06142965ae34ff6a89c81b21730438befd5cabc42f7bf802e0	bravo_alfa_dog@mail.ru	889933567624	data/unknown/unknown.png
490	bravo_alfa_delta	95f14ac42e428ebf39241ed13cf89ae1532f2e9c961767f674f1e49262bfd306	bravo_alfa_delta@mail.ru	800295306025	data/unknown/unknown.png
491	bravo_alfa_gamma	e62cde888df5f942d2b6d10b63b79e3e0a05421b4e964a73ed971bcad918899a	bravo_alfa_gamma@mail.ru	770022265852	data/unknown/unknown.png
492	bravo_delta_city	37d61613841e071b2dceed97507aecd9e86c7e2ab680c1cf0dc7dcab0e44eb0c	bravo_delta_city@mail.ru	840608529857	data/unknown/unknown.png
493	bravo_delta_town	f41948b23686bdd430a2e6e307683a61d9a29bbfd7e192010e83aa5253e9f007	bravo_delta_town@mail.ru	483597372986	data/unknown/unknown.png
494	bravo_delta_food	bd5a20f861c18438753e2e6ad032de5e139e0ada7ddaa1c0dd8ffeabbed270d1	bravo_delta_food@mail.ru	492288654806	data/unknown/unknown.png
495	bravo_delta_cat	0fb984c05857a64a5e350133a396105c6d046326ebae7e93350cb36b53ec0c9b	bravo_delta_cat@mail.ru	305175145049	data/unknown/unknown.png
496	bravo_delta_human	7b0d4afece93f46561b214d804077347a0848ea257854dbb81d2ada4008654ab	bravo_delta_human@mail.ru	789821700045	data/unknown/unknown.png
497	bravo_delta_dog	a4efbbb542083df154054a42e59a0e69644e3d63d28f0ad4390595239f380035	bravo_delta_dog@mail.ru	735023669719	data/unknown/unknown.png
498	bravo_delta_alfa	493d475b185a6c6d3b494e74faa3ccdab27ccef5e5906f2a8c79590b1ff71d30	bravo_delta_alfa@mail.ru	764506490518	data/unknown/unknown.png
499	bravo_delta_gamma	d7a5046d348fc87ff2504272ab53d66e0428d98cb9c61b778f928dedc2302e58	bravo_delta_gamma@mail.ru	615659375260	data/unknown/unknown.png
500	bravo_gamma_city	db40ee3eddb0a144510681f9978cadbe83e0fbfeb3a1bd26dfeac2b3aff53b6f	bravo_gamma_city@mail.ru	579372739485	data/unknown/unknown.png
501	bravo_gamma_town	708eb855cdc34a0ddb8a2a640af7e4d9944d9d1c0073ed760e6ddc69ebd36b4a	bravo_gamma_town@mail.ru	692411533500	data/unknown/unknown.png
502	bravo_gamma_food	1c554af511a8d27c5d403377e455835ab06fb2bda1ae40b3e915a3848db2f011	bravo_gamma_food@mail.ru	590925891776	data/unknown/unknown.png
503	bravo_gamma_cat	b4be8a22f9f9981cbd7b8ac5251e5349c577c6ebf65725ff66b944493ba5e1f8	bravo_gamma_cat@mail.ru	282921073114	data/unknown/unknown.png
504	bravo_gamma_human	e666639dad6337d2d456458670980ec0f73054201650552fcf496ad3b7e939ee	bravo_gamma_human@mail.ru	719470724249	data/unknown/unknown.png
505	bravo_gamma_dog	bba9f7927af53a75856a64cf65e50d679759c4e12626c2e21a8b4a1d6d8d0c1f	bravo_gamma_dog@mail.ru	293876134850	data/unknown/unknown.png
506	bravo_gamma_alfa	7142603089b331ea21d7a303c072eb44b2d8257fa3b06a82b62590b46c5930c5	bravo_gamma_alfa@mail.ru	632457323685	data/unknown/unknown.png
507	bravo_gamma_delta	e2926333adb53e00a4bb76e0baab73c1a54d0f1a234ee93115148d799bd29c45	bravo_gamma_delta@mail.ru	131438108417	data/unknown/unknown.png
508	alfa_city_town	80a7c9d920781140ca1580939b369995499d12a16b03f770c1830944998d3543	alfa_city_town@mail.ru	280019759887	data/unknown/unknown.png
509	alfa_city_food	2fe3ebb3f190f295240dc345bf025443aecc76ed397f47f2661e7f2f69887336	alfa_city_food@mail.ru	232491206218	data/unknown/unknown.png
510	alfa_city_cat	345d7d84dc396f1f2e935714693533432eb0efcfb7a88be4755495145568eba6	alfa_city_cat@mail.ru	207512665733	data/unknown/unknown.png
511	alfa_city_human	bf88eb211840d7b2728c4df3d340b09870f230e7fbd4a79c2bfb0696f2ffdfd9	alfa_city_human@mail.ru	386037049883	data/unknown/unknown.png
512	alfa_city_dog	0cfe4120bc0c90b609839227661314a1a627af692e0756398384097778979b7f	alfa_city_dog@mail.ru	319726617047	data/unknown/unknown.png
513	alfa_city_bravo	fcace27265a1c67675ce972dee3c3615f34b9db93de1e5615e466a278f2220fb	alfa_city_bravo@mail.ru	817031715429	data/unknown/unknown.png
514	alfa_city_delta	eb0e7e6a7f386aa9d782cb6476dd7d99fe699666dea0c7a732dddee10ba3336b	alfa_city_delta@mail.ru	814394143880	data/unknown/unknown.png
515	alfa_city_gamma	70a754eccda4e796dcabf1d7e6ed6c6c8c7debf60dc9cf2b56eacf819996b7ad	alfa_city_gamma@mail.ru	569526702495	data/unknown/unknown.png
516	alfa_town_city	7155bb5873d6e6d0b2352c8c6b8d6110cfb5b04d7abe4ec30de7efb0ff44bf7a	alfa_town_city@mail.ru	523616924412	data/unknown/unknown.png
517	alfa_town_food	0caead4393febfe6bca78c445b979e561a9b4e5aee0b2279c15e142f88e5805b	alfa_town_food@mail.ru	761952115489	data/unknown/unknown.png
518	alfa_town_cat	a78da32c4c35fa8236066c827bf6054e0a2d362ee3f03780d200af39088f7f6a	alfa_town_cat@mail.ru	348314655114	data/unknown/unknown.png
519	alfa_town_human	5772abca94905fc57381c4e2a27f188f6853a8bdf9d309b2c8bdaf8a14010a01	alfa_town_human@mail.ru	586030053000	data/unknown/unknown.png
520	alfa_town_dog	b7c77e8502eb8bc5d95889bb4934ceebb43357dab5522b8e11a3892bb7a94e4f	alfa_town_dog@mail.ru	615658373614	data/unknown/unknown.png
521	alfa_town_bravo	4e85da5d459a41a9f86494f2be865c5ac42972200642a7f62632022611bc6b1f	alfa_town_bravo@mail.ru	320766928374	data/unknown/unknown.png
522	alfa_town_delta	13891ffa910cca8a213878e41be59bda5b9dbf56afba91c885b2c398162cc225	alfa_town_delta@mail.ru	820369059856	data/unknown/unknown.png
523	alfa_town_gamma	77e4f9a942f23f17d0613bcaaa1007d6c59107cf3300cf049046117baf10f63b	alfa_town_gamma@mail.ru	843223773007	data/unknown/unknown.png
524	alfa_food_city	d08d669324b5049bae6b1541f5bfb109bec0ff6aa4cea4ea6f90bc48974da97d	alfa_food_city@mail.ru	649551543065	data/unknown/unknown.png
525	alfa_food_town	59b1aed9685ebe4ce3f8be9ca193212a3d08c6e066915d39e2b8efe86058c9e0	alfa_food_town@mail.ru	98188496476	data/unknown/unknown.png
526	alfa_food_cat	54d1e15eb39227b6e670282fc216340cf75ca2f0475d4b43ab9489bdeeaf8cb8	alfa_food_cat@mail.ru	392102257016	data/unknown/unknown.png
527	alfa_food_human	a84f07560c8495f138d72794d7e4eb9370ade3264fff1ee459f0c0630a2535bf	alfa_food_human@mail.ru	724905694155	data/unknown/unknown.png
528	alfa_food_dog	9225738b50751b4ee0f070b299bf1bffc8403af2c355b28138edab8c29c8f9fd	alfa_food_dog@mail.ru	593465236211	data/unknown/unknown.png
529	alfa_food_bravo	a895c4d2ee1a0b90122b320c5b19c0c6af7d5627a6e687840822133ea8ea2a3d	alfa_food_bravo@mail.ru	429760460695	data/unknown/unknown.png
530	alfa_food_delta	6773f533427c39beb2a7fca2e238c1e34bfed0a8fa534690024882cc8af42f48	alfa_food_delta@mail.ru	455801838144	data/unknown/unknown.png
531	alfa_food_gamma	8896dcc6b415bc8908c86916b37ca3b0c66b9ea8abc2a942e383361b7accae8f	alfa_food_gamma@mail.ru	870748405700	data/unknown/unknown.png
532	alfa_cat_city	6b8563919ab83b32e6daa101cf547e5e3af94e3aacf55307ab8aabc629122476	alfa_cat_city@mail.ru	607667516298	data/unknown/unknown.png
533	alfa_cat_town	7959d5c1aa0e45dcd9efa772d5566c77a6d7facee375528d513cb15731336c37	alfa_cat_town@mail.ru	89970282344	data/unknown/unknown.png
534	alfa_cat_food	ee38efcd168c4aa16ab74ed6d61ec5d876571ed5274334e415c7073f8b463c4e	alfa_cat_food@mail.ru	514497697480	data/unknown/unknown.png
535	alfa_cat_human	38bfc3367c625d7df3bec5f4daa50ac35572eb19ec8c4864b9574ca49e61fd83	alfa_cat_human@mail.ru	484785562082	data/unknown/unknown.png
536	alfa_cat_dog	9b70718ede154325fc8736a5089decfe409753e1f38352ef23472dbb3ff2d951	alfa_cat_dog@mail.ru	335818585665	data/unknown/unknown.png
537	alfa_cat_bravo	3517287470772cff7b2fb568bf5ac7a2f34f5122bb5c3f2352184b37d78cecea	alfa_cat_bravo@mail.ru	401754195348	data/unknown/unknown.png
538	alfa_cat_delta	90fa81d0fbb0d06f331aa75f8a6707b20161fd4462f9e9700ae7618a775411de	alfa_cat_delta@mail.ru	485613793519	data/unknown/unknown.png
539	alfa_cat_gamma	5e0f6dfa51d50c1e869751003d85702fc2648171665d63e7bd32f1e68ab77679	alfa_cat_gamma@mail.ru	443197155506	data/unknown/unknown.png
540	alfa_human_city	0d21446c59d3678db940e127ecde8c5ef91e150622917beab5a00321b04c79ff	alfa_human_city@mail.ru	512124328324	data/unknown/unknown.png
541	alfa_human_town	5919127c866ee9576becfe87502462a7cfc07572336ee02615d9ae1f5cf91bcd	alfa_human_town@mail.ru	334509756067	data/unknown/unknown.png
542	alfa_human_food	9cb41557e54a9a97239dff805bfe8e2b8c1aebac7a636258d8369a09771c9d3e	alfa_human_food@mail.ru	772257989388	data/unknown/unknown.png
543	alfa_human_cat	0a2b2325b4758d192bad722bb7df9d3d974487a5bdb66bb8d03223f743580866	alfa_human_cat@mail.ru	580841640480	data/unknown/unknown.png
544	alfa_human_dog	32e05405be19c9183307375c291f842322b81770639113a1ebad522abe606406	alfa_human_dog@mail.ru	281765574642	data/unknown/unknown.png
545	alfa_human_bravo	826d29b7ee8ba0289382169d2a33ec4d85c9a8b091544f539e2f76d33e8b166d	alfa_human_bravo@mail.ru	311256062048	data/unknown/unknown.png
546	alfa_human_delta	faf6333a85e705b5bf87fd283567be02a1ae9680a31e434a2d72b9601d5cc1a6	alfa_human_delta@mail.ru	215420248586	data/unknown/unknown.png
547	alfa_human_gamma	c57808d61b077c91db21ba50d2abf0d9c55f1796e6a94789589ee0207a471dc7	alfa_human_gamma@mail.ru	719716812342	data/unknown/unknown.png
548	alfa_dog_city	cebeddd41217207a0312befe91239440686e346e599cd661a0698163a4c86451	alfa_dog_city@mail.ru	773152802666	data/unknown/unknown.png
549	alfa_dog_town	d8b686679a727545d946fb00d73bf5ed008ab4254ea64cb386fdea5b9dce1301	alfa_dog_town@mail.ru	429611305387	data/unknown/unknown.png
550	alfa_dog_food	20118b9fc1380677eb76b599316b9df4a12512efbca392fe3d83456943d31068	alfa_dog_food@mail.ru	345543974819	data/unknown/unknown.png
551	alfa_dog_cat	2695d1b4bc19328e0bc4394864d30b8873360b80d994b4298894a54521239bf2	alfa_dog_cat@mail.ru	768255492359	data/unknown/unknown.png
552	alfa_dog_human	c69574c16a2a41d925bb99025320d2a96ad182e6bc923feadcf6e1124812018f	alfa_dog_human@mail.ru	147846968244	data/unknown/unknown.png
553	alfa_dog_bravo	66ea34ae804d41b64af28755e8d88611eced014dbf40be8911b7ede23150ba8e	alfa_dog_bravo@mail.ru	330279958259	data/unknown/unknown.png
554	alfa_dog_delta	acb8f8e06eb7c40625e8fd0b29b195f5cfc0239b824728b5723c01df7b45010b	alfa_dog_delta@mail.ru	794271501572	data/unknown/unknown.png
555	alfa_dog_gamma	0dc2551d1de4ed2ab8859c6744258944cadf245aab562adaf935b03676f38c7c	alfa_dog_gamma@mail.ru	304071011935	data/unknown/unknown.png
556	alfa_bravo_city	0b51d5e99d8196e9b6e95302823e2b656f61697a8daee15f0fa8478ce5980170	alfa_bravo_city@mail.ru	776687547126	data/unknown/unknown.png
557	alfa_bravo_town	0d6a31d51de60a3aaa7c36f63c9f272cb5775ace3cebf71ff22fce44fe1ab1e4	alfa_bravo_town@mail.ru	702241856766	data/unknown/unknown.png
558	alfa_bravo_food	3deaee654699fabd3227498806734cd2f187bbb62f20e6eb75a6e3d4c520f310	alfa_bravo_food@mail.ru	227247771580	data/unknown/unknown.png
559	alfa_bravo_cat	802c05a65fb964801a926ba6da2d672ffe98d830c95436177962891c4ac8ebb8	alfa_bravo_cat@mail.ru	853059394299	data/unknown/unknown.png
560	alfa_bravo_human	8464fcc5ab95df2865dc4af0e6eaaa99a67166b06582c11b47d2fc2c2d48b6e0	alfa_bravo_human@mail.ru	646838231299	data/unknown/unknown.png
561	alfa_bravo_dog	d0c758976c31a91d2059c24a5516320c3dee63b8d10985535b0e75eb9cb04d1b	alfa_bravo_dog@mail.ru	884527137316	data/unknown/unknown.png
562	alfa_bravo_delta	1a6c7a0084c95d74dffbe33f8fa9d08064138a34ce51a541784311a1760300c3	alfa_bravo_delta@mail.ru	518341058557	data/unknown/unknown.png
563	alfa_bravo_gamma	aacf93340446ae7cdaa17ae9e8be7eda9c1d5dcd912e25123557e460d8d753dd	alfa_bravo_gamma@mail.ru	279278399156	data/unknown/unknown.png
564	alfa_delta_city	8c76c03fa5837443ef1d3e891f548ebeb6d9297b9cd2d052bd4c79ffd4dbd341	alfa_delta_city@mail.ru	310192699771	data/unknown/unknown.png
565	alfa_delta_town	52f10654f5646e6191851b496622fa05ff02c9438a907ae35794cd0b8dfa3e3a	alfa_delta_town@mail.ru	163585342036	data/unknown/unknown.png
566	alfa_delta_food	e0586abbd095ce22ec165406ac5e940ab36a89abe72e7382a6ddb2dd0ee82864	alfa_delta_food@mail.ru	846287299165	data/unknown/unknown.png
567	alfa_delta_cat	b24b03a9b15c0e3893d3da6402d74e622271084a1a8f3a65f0e5a40172de8fa6	alfa_delta_cat@mail.ru	299616045332	data/unknown/unknown.png
568	alfa_delta_human	d43fcec6cdca3870db0b6d0cc458c77566683182ba78945fab344d2aae76b9e8	alfa_delta_human@mail.ru	260210193552	data/unknown/unknown.png
569	alfa_delta_dog	23ea9e69142df6ec1b2dd99f099ae8eaeea97bf3e1f7317c80ab22d4184a7504	alfa_delta_dog@mail.ru	344212200882	data/unknown/unknown.png
570	alfa_delta_bravo	9f69f9effaeb1f9c5546784c7cd2c43c17b3d76d517d849507e60be3967f2a33	alfa_delta_bravo@mail.ru	163323004208	data/unknown/unknown.png
571	alfa_delta_gamma	d6c6b32d0d29da1f3430b52364e537ed1d3cc25b834c1483d223e3a90da2a7e5	alfa_delta_gamma@mail.ru	586045640828	data/unknown/unknown.png
572	alfa_gamma_city	f9d6669c762c4375a760cb19a72e65ecdea2e4b7e02a3768d59e067af7f666ac	alfa_gamma_city@mail.ru	241313659532	data/unknown/unknown.png
573	alfa_gamma_town	ea0ff4fb6591cf69513e0b86b4dbc0bc817c3b4358036a2b6eda73cbc1d26bea	alfa_gamma_town@mail.ru	609697042678	data/unknown/unknown.png
574	alfa_gamma_food	0eb715cc882d667a26c0c5c6d81b165406b339e438407cd1a27024604698319e	alfa_gamma_food@mail.ru	489986313552	data/unknown/unknown.png
575	alfa_gamma_cat	2650e6ee607e1259c1c3473dae6b14b5f8879d1c570154b09d1ddc646071ce84	alfa_gamma_cat@mail.ru	263510696800	data/unknown/unknown.png
576	alfa_gamma_human	f8398587310b8a467a748d5a4a2fc358d9aa76bae25c6ef98106815301ab4b75	alfa_gamma_human@mail.ru	386496883403	data/unknown/unknown.png
577	alfa_gamma_dog	22774e4b4cf87920456047ffa9971cc5719cdab4adfeee71d884fdb4cc9d55d7	alfa_gamma_dog@mail.ru	339434117497	data/unknown/unknown.png
578	alfa_gamma_bravo	f1b521fbcf11a590816bd32890d681916fb7571225c5a0dad1094daf64e9a361	alfa_gamma_bravo@mail.ru	849760797243	data/unknown/unknown.png
579	alfa_gamma_delta	93bbd0c6bac93709a43cd7cd376be3ff026f7ba0f1c4db2e4aaf9e910ab67aef	alfa_gamma_delta@mail.ru	253332560242	data/unknown/unknown.png
580	delta_city_town	2cf191dde43ae6215ad5872c570c2db6f28f701b348692bea4b6242f97a89baa	delta_city_town@mail.ru	568545718224	data/unknown/unknown.png
581	delta_city_food	05adf055c9823080aa570aab35d98634cc1b6b2ed82679668b1ba99318c649b9	delta_city_food@mail.ru	878806590776	data/unknown/unknown.png
582	delta_city_cat	ee70e110f7184d9657efd1cd10c17be84094f28ae7125e680e6bedcb718365f2	delta_city_cat@mail.ru	224335681496	data/unknown/unknown.png
583	delta_city_human	0a06792d627136ddb62228a4090aef32b68b045da9318707b7ae72d5ace24926	delta_city_human@mail.ru	840308588156	data/unknown/unknown.png
584	delta_city_dog	d83f2de60cee586f01574d04325042aa1a4d1b06a716f493b8406e441cbfe85a	delta_city_dog@mail.ru	446457283128	data/unknown/unknown.png
585	delta_city_bravo	551e406b03d40b65b7fe17acc2c586b3ff73ae74ee45260d6a6e3ae37e5644b0	delta_city_bravo@mail.ru	760552140219	data/unknown/unknown.png
586	delta_city_alfa	942913e2074412dec4d289643f919514be10c2a9f5cb1a161250b3b990fe0921	delta_city_alfa@mail.ru	801003238184	data/unknown/unknown.png
587	delta_city_gamma	b5d41b289b923ff240ef1575900484708411228fb87841f2b07c6c6fe859b117	delta_city_gamma@mail.ru	321713517265	data/unknown/unknown.png
588	delta_town_city	ea47c669342a671725e1e1b1b74e6bce9fa1a0bf85b483c4f47361fb57999f8e	delta_town_city@mail.ru	460670380354	data/unknown/unknown.png
589	delta_town_food	1b1df1c4860b4490e4e609b1c8e14521dec224ccaae0f40bb78eda4cc7dce1bf	delta_town_food@mail.ru	529665452734	data/unknown/unknown.png
590	delta_town_cat	6397140c71f28ea6a963886b544f74f5ec27bcfc0ff2573e555679f3b068f038	delta_town_cat@mail.ru	183695053273	data/unknown/unknown.png
591	delta_town_human	6a4f6de9175f1b3a72835286cca9cb123d1476338af82d239f722ad07f0651d1	delta_town_human@mail.ru	530160114092	data/unknown/unknown.png
592	delta_town_dog	a2dcde379fa1b81f0f03f56a1222f0b36953f18f5e4a5398041b983230fa226c	delta_town_dog@mail.ru	104943531171	data/unknown/unknown.png
593	delta_town_bravo	5c31ba732e637ad254b4199bd08403b227691a0e8df7cd20c0df17418bf0a12e	delta_town_bravo@mail.ru	251526876432	data/unknown/unknown.png
594	delta_town_alfa	c7a9cfcc337b3a6a6f8179f2e5126972d6f246de16299581f950000d5cc2a2c0	delta_town_alfa@mail.ru	177929973381	data/unknown/unknown.png
595	delta_town_gamma	77a606186f9c199341edffe9bc6f65982487b3e4e17802bc63771a1bc5f586b5	delta_town_gamma@mail.ru	449696536203	data/unknown/unknown.png
596	delta_food_city	cbbb84d58896ee34057dd61f805e7429fe6ae03100bb3468487d03495966649a	delta_food_city@mail.ru	640912460313	data/unknown/unknown.png
597	delta_food_town	834ff4a8bc52c950918eea6d99b7fd493c591f712422a5b9017db54ed74dfff6	delta_food_town@mail.ru	245653869257	data/unknown/unknown.png
598	delta_food_cat	06ed22485573510b512d348a2a6ff0c4c94f17ba4e4280f36ad2ca37e1aec800	delta_food_cat@mail.ru	411927635941	data/unknown/unknown.png
599	delta_food_human	179419d3554e61fdcc7d2bad8d50859f74e905ceaf912bc35e5896e3e0d77b4c	delta_food_human@mail.ru	587149321305	data/unknown/unknown.png
600	delta_food_dog	fbd7cd56484438863ae6a5836bd5827bd71c7a1f8b5304875f8b955153658bbf	delta_food_dog@mail.ru	238816934971	data/unknown/unknown.png
601	delta_food_bravo	058e94e95490fbc37fa32bf17bd2f6ea921ae6093bd69cab4d03a0157821d684	delta_food_bravo@mail.ru	407023930202	data/unknown/unknown.png
602	delta_food_alfa	dcef17814d6613d0a56248cdf3954be4524cb1dec967d1975969b1773cb6fc98	delta_food_alfa@mail.ru	146175063531	data/unknown/unknown.png
603	delta_food_gamma	d86c4f7db8cb48dccdd2e3fc7523203b70088dee49428182e4d834f828f5df1b	delta_food_gamma@mail.ru	119983294850	data/unknown/unknown.png
604	delta_cat_city	a52c1ca1b276223a4d74f22c678cf112bdb963b81f8f132b58f6a4433b13ada6	delta_cat_city@mail.ru	383593849046	data/unknown/unknown.png
605	delta_cat_town	387c0d4b7fff663e01531bd25095be908a9ace025d9ce99f3b1de81e37260082	delta_cat_town@mail.ru	215688787443	data/unknown/unknown.png
606	delta_cat_food	4d9df2a59c2c55405905aa819939e037c81cb3dbcc8f4666423495fb62dce2d6	delta_cat_food@mail.ru	487456746139	data/unknown/unknown.png
607	delta_cat_human	a974d6ae93d356f1892193f651e68724518e43017f44f9148bb7b9341b2a6ec5	delta_cat_human@mail.ru	135142123523	data/unknown/unknown.png
608	delta_cat_dog	2e7c799de389d683a3825422bf41989857195f981395858610a683387bb4b5d9	delta_cat_dog@mail.ru	749029046357	data/unknown/unknown.png
609	delta_cat_bravo	52d0b39716a84f65e0bcd51dca76aa5c5d560c55ba5349b412ec443c4b1092b0	delta_cat_bravo@mail.ru	390114381973	data/unknown/unknown.png
610	delta_cat_alfa	1780a3627b192ae27a76e5c8dffa7c04aea9d76ed8b0bb03320229f24149face	delta_cat_alfa@mail.ru	709548120787	data/unknown/unknown.png
611	delta_cat_gamma	c83e5df9c969e2be283e08ddd96639b9966c30f7b8737cb332046b25bbe8db79	delta_cat_gamma@mail.ru	650576861236	data/unknown/unknown.png
612	delta_human_city	b7c9a999407ca7e13ab96f1c0ec1075a0e9a0463682afc64a0ce7c996033906e	delta_human_city@mail.ru	513834062467	data/unknown/unknown.png
613	delta_human_town	01953e026fbed4f91359752b3252d434b5fcf6368960a6219a3fafaf955ef26e	delta_human_town@mail.ru	102491935713	data/unknown/unknown.png
614	delta_human_food	dcd0e57cf6257b0e46dabe8633528d12e6aa1d0cb66ed0eb0f5de9133ecbae02	delta_human_food@mail.ru	672356426639	data/unknown/unknown.png
615	delta_human_cat	78988695a6a4b5cde0c61dc3984765dacd94cdc44587e5857eca16558aa33b19	delta_human_cat@mail.ru	730453439112	data/unknown/unknown.png
616	delta_human_dog	70e5cad4b01ab6048dbd87d60a43058986ba2bdbd50da9a1660d4eee2612dbc4	delta_human_dog@mail.ru	732100892070	data/unknown/unknown.png
617	delta_human_bravo	763d92ca6dcffe030e3e62cccd9cdafcecd9de8865026749839afa239e1a0d56	delta_human_bravo@mail.ru	719363880017	data/unknown/unknown.png
618	delta_human_alfa	2066820e7c090d76414a2ac5ee1a35473f5376bb0d91d27226f466e44993e1c4	delta_human_alfa@mail.ru	578757966120	data/unknown/unknown.png
619	delta_human_gamma	717b9014b62f3e66a300d5880fc458c3e27ec29ed7d7f3635c31880afa7ccbe2	delta_human_gamma@mail.ru	334472209911	data/unknown/unknown.png
620	delta_dog_city	6f75428ee31966a3760c7977cb3c03e640ba8bc2811a561e3336362eb3713014	delta_dog_city@mail.ru	444461323690	data/unknown/unknown.png
621	delta_dog_town	ff9f7d9c137c7dadad1d8167274d7dae02de996ace1e42767549483148f0d308	delta_dog_town@mail.ru	868421522540	data/unknown/unknown.png
622	delta_dog_food	c36edadb2f4d5cfaababff9a47e65d9ba8800923443380cda9589966824c3f50	delta_dog_food@mail.ru	672366384669	data/unknown/unknown.png
623	delta_dog_cat	96761b9d1e50cb70c240729b60a003fcfe5b5d19f73842659b1afad3c0fae3f6	delta_dog_cat@mail.ru	781465632158	data/unknown/unknown.png
624	delta_dog_human	44ae9346eb07d43b9e75bab247e5025399e8999cd305416d67a907867a2d0332	delta_dog_human@mail.ru	106413013381	data/unknown/unknown.png
625	delta_dog_bravo	d044bf13e35a0ce0dc6e1be3cb49981da10480f0d1ac97e5ac4ecc6decca85b1	delta_dog_bravo@mail.ru	732880342960	data/unknown/unknown.png
626	delta_dog_alfa	27fffe1c83deb25f4f65eab89b534cb6e9f111c443d683b894694101b768970a	delta_dog_alfa@mail.ru	159225333894	data/unknown/unknown.png
627	delta_dog_gamma	4c88b7b413af29fa171a4e4bd4449ebcc27b913edd3508d39b21a51d4702be55	delta_dog_gamma@mail.ru	357959762086	data/unknown/unknown.png
628	delta_bravo_city	0c66207a951154b692b35ebf9765c57ddca1c3b4f3c2d45b69fbaa18d5bb2772	delta_bravo_city@mail.ru	144197989087	data/unknown/unknown.png
629	delta_bravo_town	6f8a3aa7230d0b539ffad0450476bef5ffe4004a9e5583413ea8ada28e920466	delta_bravo_town@mail.ru	306325645382	data/unknown/unknown.png
630	delta_bravo_food	debe494feff81d7cc3f6604f9fdd695b9339316abc58b137e8823ae7f6c71b97	delta_bravo_food@mail.ru	565568942976	data/unknown/unknown.png
631	delta_bravo_cat	dbf94789032a204c1a0092d159e0a9fec78150383b09afdd1b4ff762b04d970a	delta_bravo_cat@mail.ru	140220011610	data/unknown/unknown.png
632	delta_bravo_human	59ff4f442f4f478a92131e3cebc309f8980b4ecefef3a52ba2a805fc350a8617	delta_bravo_human@mail.ru	842107175242	data/unknown/unknown.png
633	delta_bravo_dog	c36e6cf4f80d02f268167bb82cda3c2d51870f9b688a689cd031e7182df875f4	delta_bravo_dog@mail.ru	164284649339	data/unknown/unknown.png
634	delta_bravo_alfa	9339f2ac94499da12b2751a0eaea37c96e04e4a08e1807893689f098be89e409	delta_bravo_alfa@mail.ru	285297809769	data/unknown/unknown.png
635	delta_bravo_gamma	6facbe1065c6dd814133eed0d67ed48bc5433a6caf3c536c377a1005a599b71b	delta_bravo_gamma@mail.ru	733055913346	data/unknown/unknown.png
636	delta_alfa_city	b90efdb17559ca149fb467b73c8af21647bc1a0ccb6ddea4596e40f2159eea00	delta_alfa_city@mail.ru	898484719873	data/unknown/unknown.png
637	delta_alfa_town	4b090fabf7655dc9f54a889231c84dfb9403bf50c5d766e4182a2d9b8dc19462	delta_alfa_town@mail.ru	794321134593	data/unknown/unknown.png
638	delta_alfa_food	c8083dd5affcf61eb04c9cc86f046e5cd5ce197bfcfda78ce15a1c2d7e92d36b	delta_alfa_food@mail.ru	243975224021	data/unknown/unknown.png
639	delta_alfa_cat	040701927d3f3e63a9186f8badae5789c7aa1d5b2d030d4ed282ec1da8f356f4	delta_alfa_cat@mail.ru	618595658646	data/unknown/unknown.png
640	delta_alfa_human	786ec0f322351690694b6217c9c6a59b4b0d46aa3853e67672c68be1358ea64b	delta_alfa_human@mail.ru	838456690430	data/unknown/unknown.png
641	delta_alfa_dog	7771a60030670921b02ca2308cc68a5501e4beefda4c14c7a040766aaa117a19	delta_alfa_dog@mail.ru	487342514792	data/unknown/unknown.png
642	delta_alfa_bravo	77a38b852d679c39ba9c4fb4c70e26767c367fafbd8150749103c2f44d8e0d26	delta_alfa_bravo@mail.ru	613634789171	data/unknown/unknown.png
643	delta_alfa_gamma	ae8c9725b9b6d6dffa4a0a20663a280f70971edbbba8ce7717e077874728bb92	delta_alfa_gamma@mail.ru	226384741227	data/unknown/unknown.png
644	delta_gamma_city	ab0a7a8de233109cdcd742eb04eb74a3bfc6384233df1eb16f6348e920cbfe04	delta_gamma_city@mail.ru	174662773570	data/unknown/unknown.png
645	delta_gamma_town	0fb523ffdf1f0c6e55933c55f5ffde2262ba599079cb0cd59538776897f3f5a2	delta_gamma_town@mail.ru	854229626197	data/unknown/unknown.png
646	delta_gamma_food	6f7e6939f7140472c2e3f9c4f30bfb5c158789cbff69da5a9ce05e925764f385	delta_gamma_food@mail.ru	289459052645	data/unknown/unknown.png
647	delta_gamma_cat	bbebf3b1fc4b7d2792367e40c625963e9c9b204987bb5bbc85b945b2837c2669	delta_gamma_cat@mail.ru	675030594926	data/unknown/unknown.png
648	delta_gamma_human	23a216cea5cb2090bbd5a78928a9ea5f94eda0cab893122af7a7c3f32fe90a28	delta_gamma_human@mail.ru	603434122745	data/unknown/unknown.png
649	delta_gamma_dog	94e30d06b9cde95d192405dcf68461a0f12c61a8851c260df09695041cc2913e	delta_gamma_dog@mail.ru	142043509012	data/unknown/unknown.png
650	delta_gamma_bravo	65a8b14810d292ebe85e5c26fd8b533d6fddc4dd8e281257dc90ef921f57b765	delta_gamma_bravo@mail.ru	510556709832	data/unknown/unknown.png
651	delta_gamma_alfa	9cb969f100fe0c9578b929b46a3d7d2eb41add45548f247a3af2fe86e15cbcc9	delta_gamma_alfa@mail.ru	724157225382	data/unknown/unknown.png
652	gamma_city_town	e3104472e67ef3388ce34dd49a9d8345d67d708c22f41eb6d80338010c167eb8	gamma_city_town@mail.ru	780213981548	data/unknown/unknown.png
653	gamma_city_food	af1125fdd2308a776adc82c9a82e849fecef1d35625b5d4ac31fcdacc5b80ffc	gamma_city_food@mail.ru	660519060330	data/unknown/unknown.png
654	gamma_city_cat	c45a10a7f08928ccb105602906cba3b10d77b7189d18fea7238783503667180b	gamma_city_cat@mail.ru	352135592627	data/unknown/unknown.png
655	gamma_city_human	dad5f714b19843ebc2744dcc1ef57b98a2070ecbeab1baac366f2cf58bc4792c	gamma_city_human@mail.ru	304600216416	data/unknown/unknown.png
656	gamma_city_dog	963c475235c6f3fda19617ecc6d330d6d1c1a5f79c98d556e0125130b06f4a71	gamma_city_dog@mail.ru	475338405316	data/unknown/unknown.png
657	gamma_city_bravo	628181819e39ca35d113d10c62132e03774e8f01f51e25c6e0249a99b58b92a8	gamma_city_bravo@mail.ru	783283649517	data/unknown/unknown.png
658	gamma_city_alfa	c5b1b5dcb0a87c25362d7e22cb475be1d1c9fc649993493b030e9539aadba1b2	gamma_city_alfa@mail.ru	203564490213	data/unknown/unknown.png
659	gamma_city_delta	ab3b91884ddafc46999b0e7611ce578352eab453835099989dd81933c4185897	gamma_city_delta@mail.ru	410376069721	data/unknown/unknown.png
660	gamma_town_city	7acc3937d4a8e8b5505fb0bfb227bb4930f7b3916d7391b1c6c6825c6cf84e8f	gamma_town_city@mail.ru	695550282537	data/unknown/unknown.png
661	gamma_town_food	ef97ae9b51ec932418e6c6c27f2c0c8f452302dcd4f06ef90745980d6ddc261b	gamma_town_food@mail.ru	613056862965	data/unknown/unknown.png
662	gamma_town_cat	7ab6e25876a8d5b65a3c497c20d53a29ea77d4789b13f2130276174e64dcb914	gamma_town_cat@mail.ru	834082846251	data/unknown/unknown.png
663	gamma_town_human	db3dfe1e5f75c8a4d9c2a5e89ecbe2eb83c12c2894593aaff36a5d8ac01dbbc0	gamma_town_human@mail.ru	626247381319	data/unknown/unknown.png
664	gamma_town_dog	e07f55cdf41d5887705c2041b73615ec4299c744e57a1636c7476a9969d7b5c5	gamma_town_dog@mail.ru	169131016985	data/unknown/unknown.png
665	gamma_town_bravo	06f8bd1951344669bc8a113e2a8c73c8856e1d835f76ee63b222eab8ff6971ae	gamma_town_bravo@mail.ru	309954563967	data/unknown/unknown.png
666	gamma_town_alfa	6433f076478ce66b3dcf33ff2420a1c3383b34dab558df910d401b0398bbaedc	gamma_town_alfa@mail.ru	264902994432	data/unknown/unknown.png
667	gamma_town_delta	4a3f6516df8f53684d20a50f00a76e81fbf0a52bc41965e7ae966490d4faa664	gamma_town_delta@mail.ru	531656507363	data/unknown/unknown.png
668	gamma_food_city	ba0e558dc387904ed7de6b80fb24294c6d50a042ff16cdcd7f08477f61ede04f	gamma_food_city@mail.ru	192798903822	data/unknown/unknown.png
669	gamma_food_town	668637f1e85627e311a416df71784b79bd297429c50624647f218c7b643ec811	gamma_food_town@mail.ru	806355121052	data/unknown/unknown.png
670	gamma_food_cat	96f45a97e987b7c5f0263c6cdff2020477eae9c245ae39227eb0186446f7e0df	gamma_food_cat@mail.ru	620649485622	data/unknown/unknown.png
671	gamma_food_human	be9a7df7099fe1b35912a5306676161fb492c33d855a2c7c3b86188ef826781c	gamma_food_human@mail.ru	778311715077	data/unknown/unknown.png
672	gamma_food_dog	36a6fea0f88dccc7b592931759ba0a745c7f02d37377455f17933ff011f17130	gamma_food_dog@mail.ru	695634300830	data/unknown/unknown.png
673	gamma_food_bravo	a6266af5010c8e6276e1d76f50895c05c6e57c41c785704fc3c99a452d4ec5d1	gamma_food_bravo@mail.ru	282239564313	data/unknown/unknown.png
674	gamma_food_alfa	186724020c6ec2a34e222de2c2c5356d0161ee4b054a7db7d562e77f5cb1444b	gamma_food_alfa@mail.ru	880637440825	data/unknown/unknown.png
675	gamma_food_delta	df652f83137104a093c6bfd161d58e926032bcd78679895b90b64799645e5b07	gamma_food_delta@mail.ru	275550981214	data/unknown/unknown.png
676	gamma_cat_city	8f91082655eba2d0547f861401f1e6e7e4c022d17dc13a713394c9c42884aa24	gamma_cat_city@mail.ru	434862607172	data/unknown/unknown.png
677	gamma_cat_town	fef170d6966c5a4c84d79e8dc74c8493d628043516e0e6ce874174e2ad07ac81	gamma_cat_town@mail.ru	754657553334	data/unknown/unknown.png
678	gamma_cat_food	cfdf03d7d2b1147c8653e0340f8860118b62da0115bb6274e9209e526304bed9	gamma_cat_food@mail.ru	790992097145	data/unknown/unknown.png
679	gamma_cat_human	6ed7c8dab1c2dea3d5d47c35377101410f47fde38b395c1ce7fda4e3dd78c7fc	gamma_cat_human@mail.ru	476474627846	data/unknown/unknown.png
680	gamma_cat_dog	acd4af774c4a791b13fcf99f6ccd947585cb84b80724de3a023e8fd53f6d9ae5	gamma_cat_dog@mail.ru	728737344413	data/unknown/unknown.png
681	gamma_cat_bravo	59a046c280462b8bd5060a1c6d94d46c8da5eb822c698dfb54348e501c17e03d	gamma_cat_bravo@mail.ru	312615448830	data/unknown/unknown.png
682	gamma_cat_alfa	9ce2787b0cd469ad5e0eabcdd04306f29cdad369546c781245e62b70c1eacf51	gamma_cat_alfa@mail.ru	164037222397	data/unknown/unknown.png
683	gamma_cat_delta	8a2ae1ad7d72995fa816d38b327345b7ed8a7548a905407b7c0134278f24883a	gamma_cat_delta@mail.ru	309222771286	data/unknown/unknown.png
684	gamma_human_city	b36373b17a830e9460e5bb4535a0961177fb96d9b0b98c4ac6714493f055670a	gamma_human_city@mail.ru	343765686592	data/unknown/unknown.png
685	gamma_human_town	c25c3df6f084f208aa52bff33336027148bb3619bdc9eff50e57bb71a52ca140	gamma_human_town@mail.ru	123831477899	data/unknown/unknown.png
686	gamma_human_food	afd585c63d7d422a4d5034187bf9370d339ffbb344d12e0d7e96c7b7721d7807	gamma_human_food@mail.ru	896877950553	data/unknown/unknown.png
687	gamma_human_cat	bd6d531ded6a39603ca8f8673b32a5c436cd49e2aa5f4fc7a49b628fd34753f8	gamma_human_cat@mail.ru	589231909519	data/unknown/unknown.png
688	gamma_human_dog	0d2521e39f820e1786f634c1ee29835defeef8f3ddd3b461c4a1e5bc6f739176	gamma_human_dog@mail.ru	611562432844	data/unknown/unknown.png
689	gamma_human_bravo	4c926c6102cb418a6d19be763e32d571cbf3d1351f3d81bef9303cacc1b1358a	gamma_human_bravo@mail.ru	107918549685	data/unknown/unknown.png
690	gamma_human_alfa	774c194ad75714c0d5faa2dd524ff620217890d9724d73f83622a2a14b5979f6	gamma_human_alfa@mail.ru	177102544142	data/unknown/unknown.png
691	gamma_human_delta	71e710c99d4d021c006df75f84ad2c1b8d1da110860b6e736bb7cd1049e180fe	gamma_human_delta@mail.ru	403616339601	data/unknown/unknown.png
692	gamma_dog_city	ea2157c2beb4ed5345afb6773b4e887b20bf1e2570c270d73ea594ea35a78de3	gamma_dog_city@mail.ru	312633677729	data/unknown/unknown.png
693	gamma_dog_town	0910ebe93b062622b64acb02cf65eeefee5558816b9d15188eae48ed06530615	gamma_dog_town@mail.ru	637174460151	data/unknown/unknown.png
694	gamma_dog_food	a923e9a61b1181a7ac440950d9d36c189e9af58f59afc9d5198f067bcc99b75d	gamma_dog_food@mail.ru	298856826645	data/unknown/unknown.png
695	gamma_dog_cat	5e1bcf84212b92c6b2ce8fdd9ed08ccc4cfe7865b23f254f97289dceeeca7048	gamma_dog_cat@mail.ru	444011182075	data/unknown/unknown.png
696	gamma_dog_human	f2851c71a50f823d48fc66096f14fb9178dc6dc2acf5a22df6db670bf448823b	gamma_dog_human@mail.ru	663323031718	data/unknown/unknown.png
697	gamma_dog_bravo	c3ad246e92d10a82873fddc0e32f923c2b189d9f1f7aa2a374dcd682231aaa86	gamma_dog_bravo@mail.ru	767892707205	data/unknown/unknown.png
698	gamma_dog_alfa	dd0ee89b8415917ec8ff84d90e339602d6ba702e6a410537f6bd48a6404974f0	gamma_dog_alfa@mail.ru	724593021894	data/unknown/unknown.png
699	gamma_dog_delta	d393484303674711a967a918864b808497be2b3d42197ffac1fd7cb8583aa66b	gamma_dog_delta@mail.ru	497637637973	data/unknown/unknown.png
700	gamma_bravo_city	9eecc0a3d38fe221a443d3779db32ef0eec2f1ff441b205e3e42fe647dd260ec	gamma_bravo_city@mail.ru	592379802744	data/unknown/unknown.png
701	gamma_bravo_town	59ce93db2fc258619334dade8c8f46de3c6db26225a9b58ee66b78a053f6d1af	gamma_bravo_town@mail.ru	317614695802	data/unknown/unknown.png
702	gamma_bravo_food	663411057b62241c2214f68087a8f576ca7be842be095f206edf5710e11fb591	gamma_bravo_food@mail.ru	186008987743	data/unknown/unknown.png
703	gamma_bravo_cat	f7398ca3bd876dd6994c401b939e975b2af8bae659b97a40de2cb642130bdac6	gamma_bravo_cat@mail.ru	791629800968	data/unknown/unknown.png
704	gamma_bravo_human	0e44c89e39fc951a56572f2f7364afbfdbde50e69d577fd7c57b01b375e74850	gamma_bravo_human@mail.ru	169888965183	data/unknown/unknown.png
705	gamma_bravo_dog	8b90c0c1c6c9a8fa16e1a74424cb34af847d3f0a1fa8d2bfd1936a5a47c48b7a	gamma_bravo_dog@mail.ru	126451897075	data/unknown/unknown.png
706	gamma_bravo_alfa	ea55a7bba222ce9e863c11b8234d5f76f0d84417432624d4c7836fde36a2c43e	gamma_bravo_alfa@mail.ru	802639540471	data/unknown/unknown.png
707	gamma_bravo_delta	805d6356bde722faab9441fadc66a062a8aab7ffd75c71ee8a7910d6dd039dc2	gamma_bravo_delta@mail.ru	692668915758	data/unknown/unknown.png
708	gamma_alfa_city	7da0d9ea8bb4e83eb708e8e0da6395c387bd3f086ff9d1762d4e06b69ddf79f8	gamma_alfa_city@mail.ru	207455253999	data/unknown/unknown.png
709	gamma_alfa_town	1a4e636f7401adfe21914b75c6cb0c3685378df4b324ea0ca44734755a493a22	gamma_alfa_town@mail.ru	515589708340	data/unknown/unknown.png
710	gamma_alfa_food	cf519477ef78ada14710e400a9f24dba86b1273ede1668946dbe9d179db25301	gamma_alfa_food@mail.ru	432689978701	data/unknown/unknown.png
711	gamma_alfa_cat	ed060c98248e00338de3a457db70d8d428720433bed31bac28549a568afad0d1	gamma_alfa_cat@mail.ru	274094139571	data/unknown/unknown.png
712	gamma_alfa_human	65a58e74483a10b3a0e0d8ecb7375bd3c827480e1c6884964ad5e22210797b21	gamma_alfa_human@mail.ru	683162616961	data/unknown/unknown.png
713	gamma_alfa_dog	75c3dde83bd8f984a6d1d1b5ad35fbf5dbd50707ec7537e2031cb3819dc96879	gamma_alfa_dog@mail.ru	667268540953	data/unknown/unknown.png
714	gamma_alfa_bravo	1ceb91c0c5115c5cfc5d5f374ce486628b78e12a681fd7c3b53b2f01937c1ecc	gamma_alfa_bravo@mail.ru	364212175191	data/unknown/unknown.png
715	gamma_alfa_delta	936b7dbe644eaa0afc585e2f531b08172c7d0e72d1b77b280b994618837fc304	gamma_alfa_delta@mail.ru	663243160298	data/unknown/unknown.png
716	gamma_delta_city	ce8bf27ae5fce53e648716202a1734cdf94bb68d1d2351349c7876669296d2d8	gamma_delta_city@mail.ru	676878043491	data/unknown/unknown.png
717	gamma_delta_town	de8a7f436c3b1a5cbb6c661617feefb1a67fb7b553bb599453aca1295c007611	gamma_delta_town@mail.ru	615369733375	data/unknown/unknown.png
718	gamma_delta_food	c4a0dca613d9e46f2b5fd9a0b68a83ac5d37fb00efad6fb86261ea7056c3b321	gamma_delta_food@mail.ru	112135100267	data/unknown/unknown.png
719	gamma_delta_cat	eb5504d2a240d4919201ddd324a680c98106456cd92d5b4876bf682d51b2b374	gamma_delta_cat@mail.ru	101504084392	data/unknown/unknown.png
720	gamma_delta_human	3139699f0164b9e370e959ace5ec05237ccd61a93e0f404722955e95d9db0964	gamma_delta_human@mail.ru	344131248754	data/unknown/unknown.png
721	gamma_delta_dog	9c231f4d013e564bc1b2289d5d820d7cae3a07e94649786e40d5e77b95a52203	gamma_delta_dog@mail.ru	370186731953	data/unknown/unknown.png
722	gamma_delta_bravo	c1acd46014dc15e361792d5fde5171f35728762545ccb64b0d742182e27a527e	gamma_delta_bravo@mail.ru	500807270823	data/unknown/unknown.png
723	gamma_delta_alfa	c10490bf2989f0db7c375b909eff5cc74e4e735ca47ff6f1d3f6f2653205c7ef	gamma_delta_alfa@mail.ru	160809476205	data/unknown/unknown.png
\.


--
-- TOC entry 3013 (class 0 OID 42041)
-- Dependencies: 213
-- Data for Name: users_liked_performer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users_liked_performer (performer_id, user_id) FROM stdin;
\.


--
-- TOC entry 3014 (class 0 OID 42054)
-- Dependencies: 214
-- Data for Name: users_playlist_relship; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users_playlist_relship (playlist_id, user_id) FROM stdin;
\.


--
-- TOC entry 3091 (class 0 OID 0)
-- Dependencies: 206
-- Name: album_album_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.album_album_id_seq', 2, true);


--
-- TOC entry 3092 (class 0 OID 0)
-- Dependencies: 210
-- Name: playlist_playlist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.playlist_playlist_id_seq', 727, true);


--
-- TOC entry 3093 (class 0 OID 0)
-- Dependencies: 208
-- Name: song_song_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.song_song_id_seq', 12, true);


--
-- TOC entry 3094 (class 0 OID 0)
-- Dependencies: 203
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 723, true);


--
-- TOC entry 2832 (class 2606 OID 49840)
-- Name: album album_album_name_creator_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_album_name_creator_id_key UNIQUE (album_name, creator_id);


--
-- TOC entry 2835 (class 2606 OID 42275)
-- Name: album album_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_pkey PRIMARY KEY (album_id);


--
-- TOC entry 2828 (class 2606 OID 41976)
-- Name: performer performer_performer_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performer
    ADD CONSTRAINT performer_performer_id_key UNIQUE (performer_id);


--
-- TOC entry 2830 (class 2606 OID 49852)
-- Name: performer performer_performer_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performer
    ADD CONSTRAINT performer_performer_id_pk PRIMARY KEY (performer_id);


--
-- TOC entry 2844 (class 2606 OID 42258)
-- Name: playlist playlist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.playlist
    ADD CONSTRAINT playlist_pkey PRIMARY KEY (playlist_id);


--
-- TOC entry 2846 (class 2606 OID 49850)
-- Name: playlist playlist_playlist_name_creator_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.playlist
    ADD CONSTRAINT playlist_playlist_name_creator_id_key UNIQUE (playlist_name, creator_id);


--
-- TOC entry 2839 (class 2606 OID 42245)
-- Name: song song_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_pkey PRIMARY KEY (song_id);


--
-- TOC entry 2848 (class 2606 OID 49844)
-- Name: song_playlist_relship song_playlist_relship_song_id_playlist_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song_playlist_relship
    ADD CONSTRAINT song_playlist_relship_song_id_playlist_id_key UNIQUE (song_id, playlist_id);


--
-- TOC entry 2850 (class 2606 OID 49854)
-- Name: song_playlist_relship song_playlist_relship_song_id_playlist_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song_playlist_relship
    ADD CONSTRAINT song_playlist_relship_song_id_playlist_id_pkey PRIMARY KEY (song_id, playlist_id);


--
-- TOC entry 2841 (class 2606 OID 49842)
-- Name: song song_song_name_album_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_song_name_album_id_key UNIQUE (song_name, album_id);


--
-- TOC entry 2852 (class 2606 OID 49846)
-- Name: users_liked_performer users_liked_performer_performer_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_liked_performer
    ADD CONSTRAINT users_liked_performer_performer_id_user_id_key UNIQUE (performer_id, user_id);


--
-- TOC entry 2854 (class 2606 OID 49856)
-- Name: users_liked_performer users_liked_performer_performer_id_user_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_liked_performer
    ADD CONSTRAINT users_liked_performer_performer_id_user_id_pkey PRIMARY KEY (user_id, performer_id);


--
-- TOC entry 2824 (class 2606 OID 42206)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 2856 (class 2606 OID 49848)
-- Name: users_playlist_relship users_playlist_relship_playlist_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_playlist_relship
    ADD CONSTRAINT users_playlist_relship_playlist_id_user_id_key UNIQUE (playlist_id, user_id);


--
-- TOC entry 2858 (class 2606 OID 49858)
-- Name: users_playlist_relship users_playlist_relship_playlist_id_user_id_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_playlist_relship
    ADD CONSTRAINT users_playlist_relship_playlist_id_user_id_pkey PRIMARY KEY (user_id, playlist_id);


--
-- TOC entry 2826 (class 2606 OID 41970)
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- TOC entry 2833 (class 1259 OID 50590)
-- Name: album_name_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX album_name_index ON public.album USING gin (lower((album_name)::text) public.gin_trgm_ops);


--
-- TOC entry 2837 (class 1259 OID 50591)
-- Name: song_name_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX song_name_index ON public.song USING gin (lower((song_name)::text) public.gin_trgm_ops);


--
-- TOC entry 2836 (class 1259 OID 49825)
-- Name: unique_album_name_at_performer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_album_name_at_performer ON public.album USING btree (album_name, creator_id);


--
-- TOC entry 2842 (class 1259 OID 49826)
-- Name: unique_song_name_in_album; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_song_name_in_album ON public.song USING btree (song_name, album_id);


--
-- TOC entry 2822 (class 1259 OID 50589)
-- Name: username_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX username_index ON public.users USING gin (lower((username)::text) public.gin_trgm_ops);


--
-- TOC entry 2870 (class 2620 OID 42198)
-- Name: song album_songs_count_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER album_songs_count_trigger AFTER INSERT OR DELETE ON public.song FOR EACH ROW EXECUTE FUNCTION public.album_songs_count_trigger();


--
-- TOC entry 2872 (class 2620 OID 42202)
-- Name: users_liked_performer performer_followers_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER performer_followers_trigger AFTER INSERT OR DELETE ON public.users_liked_performer FOR EACH ROW EXECUTE FUNCTION public.performer_followers_trigger();


--
-- TOC entry 2871 (class 2620 OID 42200)
-- Name: song_playlist_relship playlist_songs_count_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER playlist_songs_count_trigger AFTER INSERT OR DELETE ON public.song_playlist_relship FOR EACH ROW EXECUTE FUNCTION public.playlist_songs_count_trigger();


--
-- TOC entry 2860 (class 2606 OID 42212)
-- Name: album album_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(user_id);


--
-- TOC entry 2859 (class 2606 OID 42207)
-- Name: performer performer_performer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.performer
    ADD CONSTRAINT performer_performer_id_fkey FOREIGN KEY (performer_id) REFERENCES public.users(user_id);


--
-- TOC entry 2863 (class 2606 OID 42222)
-- Name: playlist playlist_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.playlist
    ADD CONSTRAINT playlist_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(user_id);


--
-- TOC entry 2861 (class 2606 OID 42276)
-- Name: song song_album_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_album_id_fkey FOREIGN KEY (album_id) REFERENCES public.album(album_id);


--
-- TOC entry 2862 (class 2606 OID 42217)
-- Name: song song_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(user_id);


--
-- TOC entry 2865 (class 2606 OID 42259)
-- Name: song_playlist_relship song_playlist_relship_playlist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song_playlist_relship
    ADD CONSTRAINT song_playlist_relship_playlist_id_fkey FOREIGN KEY (playlist_id) REFERENCES public.playlist(playlist_id);


--
-- TOC entry 2864 (class 2606 OID 42246)
-- Name: song_playlist_relship song_playlist_relship_song_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.song_playlist_relship
    ADD CONSTRAINT song_playlist_relship_song_id_fkey FOREIGN KEY (song_id) REFERENCES public.song(song_id);


--
-- TOC entry 2866 (class 2606 OID 42044)
-- Name: users_liked_performer users_liked_performer_performer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_liked_performer
    ADD CONSTRAINT users_liked_performer_performer_id_fkey FOREIGN KEY (performer_id) REFERENCES public.performer(performer_id);


--
-- TOC entry 2867 (class 2606 OID 42227)
-- Name: users_liked_performer users_liked_performer_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_liked_performer
    ADD CONSTRAINT users_liked_performer_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- TOC entry 2868 (class 2606 OID 42264)
-- Name: users_playlist_relship users_playlist_relship_playlist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_playlist_relship
    ADD CONSTRAINT users_playlist_relship_playlist_id_fkey FOREIGN KEY (playlist_id) REFERENCES public.playlist(playlist_id);


--
-- TOC entry 2869 (class 2606 OID 42232)
-- Name: users_playlist_relship users_playlist_relship_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_playlist_relship
    ADD CONSTRAINT users_playlist_relship_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- TOC entry 3021 (class 0 OID 0)
-- Dependencies: 231
-- Name: FUNCTION gtrgm_in(cstring); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_in(cstring) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_in(cstring) TO admin;


--
-- TOC entry 3022 (class 0 OID 0)
-- Dependencies: 232
-- Name: FUNCTION gtrgm_out(public.gtrgm); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_out(public.gtrgm) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_out(public.gtrgm) TO admin;


--
-- TOC entry 3023 (class 0 OID 0)
-- Dependencies: 265
-- Name: PROCEDURE add_album(_album_name character varying, _user_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.add_album(_album_name character varying, _user_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.add_album(_album_name character varying, _user_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.add_album(_album_name character varying, _user_id bigint) TO performer;


--
-- TOC entry 3024 (class 0 OID 0)
-- Dependencies: 270
-- Name: PROCEDURE add_playlist(_playlist_name character varying, _user_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.add_playlist(_playlist_name character varying, _user_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.add_playlist(_playlist_name character varying, _user_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.add_playlist(_playlist_name character varying, _user_id bigint) TO performer;
GRANT ALL ON PROCEDURE public.add_playlist(_playlist_name character varying, _user_id bigint) TO listener;


--
-- TOC entry 3025 (class 0 OID 0)
-- Dependencies: 287
-- Name: PROCEDURE add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying) TO performer;
GRANT ALL ON PROCEDURE public.add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying) TO admin;


--
-- TOC entry 3026 (class 0 OID 0)
-- Dependencies: 285
-- Name: PROCEDURE add_song_in_playlist(_song_id bigint, _playlist_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.add_song_in_playlist(_song_id bigint, _playlist_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.add_song_in_playlist(_song_id bigint, _playlist_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.add_song_in_playlist(_song_id bigint, _playlist_id bigint) TO performer;
GRANT ALL ON PROCEDURE public.add_song_in_playlist(_song_id bigint, _playlist_id bigint) TO listener;


--
-- TOC entry 3027 (class 0 OID 0)
-- Dependencies: 267
-- Name: PROCEDURE change_user_avatar(_user_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.change_user_avatar(_user_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.change_user_avatar(_user_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.change_user_avatar(_user_id bigint) TO performer;
GRANT ALL ON PROCEDURE public.change_user_avatar(_user_id bigint) TO listener;


--
-- TOC entry 3028 (class 0 OID 0)
-- Dependencies: 253
-- Name: FUNCTION check_performer(id_perf bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.check_performer(id_perf bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.check_performer(id_perf bigint) TO admin;


--
-- TOC entry 3029 (class 0 OID 0)
-- Dependencies: 250
-- Name: FUNCTION check_user(check_username character varying, check_user_password character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.check_user(check_username character varying, check_user_password character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.check_user(check_username character varying, check_user_password character varying) TO admin;


--
-- TOC entry 3030 (class 0 OID 0)
-- Dependencies: 279
-- Name: FUNCTION create_performer_user(username character varying, user_password character varying, email character varying, phone character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.create_performer_user(username character varying, user_password character varying, email character varying, phone character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_performer_user(username character varying, user_password character varying, email character varying, phone character varying) TO admin;


--
-- TOC entry 3031 (class 0 OID 0)
-- Dependencies: 281
-- Name: FUNCTION create_user(_username character varying, user_password character varying, email character varying, phone_number character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.create_user(_username character varying, user_password character varying, email character varying, phone_number character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.create_user(_username character varying, user_password character varying, email character varying, phone_number character varying) TO admin;


--
-- TOC entry 3032 (class 0 OID 0)
-- Dependencies: 266
-- Name: PROCEDURE delete_album(_album_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.delete_album(_album_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.delete_album(_album_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.delete_album(_album_id bigint) TO performer;


--
-- TOC entry 3033 (class 0 OID 0)
-- Dependencies: 278
-- Name: PROCEDURE delete_playlist(_playlist_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.delete_playlist(_playlist_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.delete_playlist(_playlist_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.delete_playlist(_playlist_id bigint) TO performer;
GRANT ALL ON PROCEDURE public.delete_playlist(_playlist_id bigint) TO listener;


--
-- TOC entry 3034 (class 0 OID 0)
-- Dependencies: 264
-- Name: PROCEDURE delete_song_in_album(_song_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.delete_song_in_album(_song_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.delete_song_in_album(_song_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.delete_song_in_album(_song_id bigint) TO performer;


--
-- TOC entry 3035 (class 0 OID 0)
-- Dependencies: 286
-- Name: PROCEDURE delete_song_in_playlist(_song_id bigint, _playlist_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.delete_song_in_playlist(_song_id bigint, _playlist_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.delete_song_in_playlist(_song_id bigint, _playlist_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.delete_song_in_playlist(_song_id bigint, _playlist_id bigint) TO performer;
GRANT ALL ON PROCEDURE public.delete_song_in_playlist(_song_id bigint, _playlist_id bigint) TO listener;


--
-- TOC entry 3036 (class 0 OID 0)
-- Dependencies: 269
-- Name: PROCEDURE dislike_performer(_performer_id bigint, _user_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.dislike_performer(_performer_id bigint, _user_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.dislike_performer(_performer_id bigint, _user_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.dislike_performer(_performer_id bigint, _user_id bigint) TO performer;
GRANT ALL ON PROCEDURE public.dislike_performer(_performer_id bigint, _user_id bigint) TO listener;


--
-- TOC entry 3037 (class 0 OID 0)
-- Dependencies: 245
-- Name: FUNCTION gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal) TO admin;


--
-- TOC entry 3038 (class 0 OID 0)
-- Dependencies: 243
-- Name: FUNCTION gin_extract_value_trgm(text, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gin_extract_value_trgm(text, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gin_extract_value_trgm(text, internal) TO admin;


--
-- TOC entry 3039 (class 0 OID 0)
-- Dependencies: 246
-- Name: FUNCTION gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal) TO admin;


--
-- TOC entry 3040 (class 0 OID 0)
-- Dependencies: 247
-- Name: FUNCTION gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal) TO admin;


--
-- TOC entry 3041 (class 0 OID 0)
-- Dependencies: 235
-- Name: FUNCTION gtrgm_compress(internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_compress(internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_compress(internal) TO admin;


--
-- TOC entry 3042 (class 0 OID 0)
-- Dependencies: 233
-- Name: FUNCTION gtrgm_consistent(internal, text, smallint, oid, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal) TO admin;


--
-- TOC entry 3043 (class 0 OID 0)
-- Dependencies: 239
-- Name: FUNCTION gtrgm_decompress(internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_decompress(internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_decompress(internal) TO admin;


--
-- TOC entry 3044 (class 0 OID 0)
-- Dependencies: 234
-- Name: FUNCTION gtrgm_distance(internal, text, smallint, oid, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal) TO admin;


--
-- TOC entry 3045 (class 0 OID 0)
-- Dependencies: 237
-- Name: FUNCTION gtrgm_penalty(internal, internal, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_penalty(internal, internal, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_penalty(internal, internal, internal) TO admin;


--
-- TOC entry 3046 (class 0 OID 0)
-- Dependencies: 240
-- Name: FUNCTION gtrgm_picksplit(internal, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_picksplit(internal, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_picksplit(internal, internal) TO admin;


--
-- TOC entry 3047 (class 0 OID 0)
-- Dependencies: 242
-- Name: FUNCTION gtrgm_same(public.gtrgm, public.gtrgm, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_same(public.gtrgm, public.gtrgm, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_same(public.gtrgm, public.gtrgm, internal) TO admin;


--
-- TOC entry 3048 (class 0 OID 0)
-- Dependencies: 241
-- Name: FUNCTION gtrgm_union(internal, internal); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.gtrgm_union(internal, internal) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gtrgm_union(internal, internal) TO admin;


--
-- TOC entry 3049 (class 0 OID 0)
-- Dependencies: 268
-- Name: PROCEDURE like_performer(_performer_id bigint, _user_id bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.like_performer(_performer_id bigint, _user_id bigint) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.like_performer(_performer_id bigint, _user_id bigint) TO admin;
GRANT ALL ON PROCEDURE public.like_performer(_performer_id bigint, _user_id bigint) TO performer;
GRANT ALL ON PROCEDURE public.like_performer(_performer_id bigint, _user_id bigint) TO listener;


--
-- TOC entry 3050 (class 0 OID 0)
-- Dependencies: 276
-- Name: FUNCTION search_albums(word character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.search_albums(word character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.search_albums(word character varying) TO admin;
GRANT ALL ON FUNCTION public.search_albums(word character varying) TO performer;
GRANT ALL ON FUNCTION public.search_albums(word character varying) TO listener;


--
-- TOC entry 3051 (class 0 OID 0)
-- Dependencies: 236
-- Name: FUNCTION search_performers(word character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.search_performers(word character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.search_performers(word character varying) TO admin;
GRANT ALL ON FUNCTION public.search_performers(word character varying) TO performer;
GRANT ALL ON FUNCTION public.search_performers(word character varying) TO listener;


--
-- TOC entry 3052 (class 0 OID 0)
-- Dependencies: 280
-- Name: FUNCTION search_songs(word character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.search_songs(word character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.search_songs(word character varying) TO admin;
GRANT ALL ON FUNCTION public.search_songs(word character varying) TO performer;
GRANT ALL ON FUNCTION public.search_songs(word character varying) TO listener;


--
-- TOC entry 3053 (class 0 OID 0)
-- Dependencies: 244
-- Name: FUNCTION set_limit(real); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.set_limit(real) FROM PUBLIC;
GRANT ALL ON FUNCTION public.set_limit(real) TO admin;


--
-- TOC entry 3054 (class 0 OID 0)
-- Dependencies: 282
-- Name: FUNCTION show_album_songs(id_alb bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_album_songs(id_alb bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_album_songs(id_alb bigint) TO admin;
GRANT ALL ON FUNCTION public.show_album_songs(id_alb bigint) TO performer;
GRANT ALL ON FUNCTION public.show_album_songs(id_alb bigint) TO listener;


--
-- TOC entry 3055 (class 0 OID 0)
-- Dependencies: 275
-- Name: FUNCTION show_favourite_playlist(id_us bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_favourite_playlist(id_us bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_favourite_playlist(id_us bigint) TO admin;
GRANT ALL ON FUNCTION public.show_favourite_playlist(id_us bigint) TO performer;
GRANT ALL ON FUNCTION public.show_favourite_playlist(id_us bigint) TO listener;


--
-- TOC entry 3056 (class 0 OID 0)
-- Dependencies: 283
-- Name: FUNCTION show_liked_performers(id_us bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_liked_performers(id_us bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_liked_performers(id_us bigint) TO admin;
GRANT ALL ON FUNCTION public.show_liked_performers(id_us bigint) TO performer;
GRANT ALL ON FUNCTION public.show_liked_performers(id_us bigint) TO listener;


--
-- TOC entry 3057 (class 0 OID 0)
-- Dependencies: 254
-- Name: FUNCTION show_limit(); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_limit() FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_limit() TO admin;


--
-- TOC entry 3058 (class 0 OID 0)
-- Dependencies: 288
-- Name: FUNCTION show_performer_albums(id_perf bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_performer_albums(id_perf bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_performer_albums(id_perf bigint) TO admin;
GRANT ALL ON FUNCTION public.show_performer_albums(id_perf bigint) TO listener;
GRANT ALL ON FUNCTION public.show_performer_albums(id_perf bigint) TO performer;


--
-- TOC entry 3059 (class 0 OID 0)
-- Dependencies: 284
-- Name: FUNCTION show_playlist_songs(id_pl bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_playlist_songs(id_pl bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_playlist_songs(id_pl bigint) TO admin;
GRANT ALL ON FUNCTION public.show_playlist_songs(id_pl bigint) TO performer;
GRANT ALL ON FUNCTION public.show_playlist_songs(id_pl bigint) TO listener;


--
-- TOC entry 3060 (class 0 OID 0)
-- Dependencies: 255
-- Name: FUNCTION show_trgm(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_trgm(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_trgm(text) TO admin;


--
-- TOC entry 3061 (class 0 OID 0)
-- Dependencies: 274
-- Name: FUNCTION show_user_playlists(id_us bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_user_playlists(id_us bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_user_playlists(id_us bigint) TO admin;
GRANT ALL ON FUNCTION public.show_user_playlists(id_us bigint) TO performer;
GRANT ALL ON FUNCTION public.show_user_playlists(id_us bigint) TO listener;


--
-- TOC entry 3062 (class 0 OID 0)
-- Dependencies: 256
-- Name: FUNCTION similarity(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.similarity(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.similarity(text, text) TO admin;


--
-- TOC entry 3063 (class 0 OID 0)
-- Dependencies: 261
-- Name: FUNCTION similarity_dist(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.similarity_dist(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.similarity_dist(text, text) TO admin;


--
-- TOC entry 3064 (class 0 OID 0)
-- Dependencies: 257
-- Name: FUNCTION similarity_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.similarity_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.similarity_op(text, text) TO admin;


--
-- TOC entry 3065 (class 0 OID 0)
-- Dependencies: 248
-- Name: FUNCTION strict_word_similarity(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.strict_word_similarity(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.strict_word_similarity(text, text) TO admin;


--
-- TOC entry 3066 (class 0 OID 0)
-- Dependencies: 238
-- Name: FUNCTION strict_word_similarity_commutator_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.strict_word_similarity_commutator_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.strict_word_similarity_commutator_op(text, text) TO admin;


--
-- TOC entry 3067 (class 0 OID 0)
-- Dependencies: 252
-- Name: FUNCTION strict_word_similarity_dist_commutator_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.strict_word_similarity_dist_commutator_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.strict_word_similarity_dist_commutator_op(text, text) TO admin;


--
-- TOC entry 3068 (class 0 OID 0)
-- Dependencies: 251
-- Name: FUNCTION strict_word_similarity_dist_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.strict_word_similarity_dist_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.strict_word_similarity_dist_op(text, text) TO admin;


--
-- TOC entry 3069 (class 0 OID 0)
-- Dependencies: 249
-- Name: FUNCTION strict_word_similarity_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.strict_word_similarity_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.strict_word_similarity_op(text, text) TO admin;


--
-- TOC entry 3070 (class 0 OID 0)
-- Dependencies: 258
-- Name: FUNCTION word_similarity(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.word_similarity(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.word_similarity(text, text) TO admin;


--
-- TOC entry 3071 (class 0 OID 0)
-- Dependencies: 260
-- Name: FUNCTION word_similarity_commutator_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.word_similarity_commutator_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.word_similarity_commutator_op(text, text) TO admin;


--
-- TOC entry 3072 (class 0 OID 0)
-- Dependencies: 263
-- Name: FUNCTION word_similarity_dist_commutator_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.word_similarity_dist_commutator_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.word_similarity_dist_commutator_op(text, text) TO admin;


--
-- TOC entry 3073 (class 0 OID 0)
-- Dependencies: 262
-- Name: FUNCTION word_similarity_dist_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.word_similarity_dist_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.word_similarity_dist_op(text, text) TO admin;


--
-- TOC entry 3074 (class 0 OID 0)
-- Dependencies: 259
-- Name: FUNCTION word_similarity_op(text, text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.word_similarity_op(text, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.word_similarity_op(text, text) TO admin;


--
-- TOC entry 3075 (class 0 OID 0)
-- Dependencies: 206
-- Name: SEQUENCE album_album_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.album_album_id_seq TO admin;


--
-- TOC entry 3076 (class 0 OID 0)
-- Dependencies: 207
-- Name: TABLE album; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.album TO admin;
GRANT SELECT ON TABLE public.album TO performer;


--
-- TOC entry 3077 (class 0 OID 0)
-- Dependencies: 205
-- Name: TABLE performer; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.performer TO admin;
GRANT SELECT ON TABLE public.performer TO performer;


--
-- TOC entry 3078 (class 0 OID 0)
-- Dependencies: 203
-- Name: SEQUENCE users_user_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.users_user_id_seq TO admin;


--
-- TOC entry 3079 (class 0 OID 0)
-- Dependencies: 204
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO admin;


--
-- TOC entry 3080 (class 0 OID 0)
-- Dependencies: 215
-- Name: TABLE dto_album; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.dto_album TO admin;


--
-- TOC entry 3081 (class 0 OID 0)
-- Dependencies: 216
-- Name: TABLE dto_performer; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.dto_performer TO admin;


--
-- TOC entry 3082 (class 0 OID 0)
-- Dependencies: 210
-- Name: SEQUENCE playlist_playlist_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.playlist_playlist_id_seq TO admin;


--
-- TOC entry 3083 (class 0 OID 0)
-- Dependencies: 211
-- Name: TABLE playlist; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.playlist TO admin;


--
-- TOC entry 3084 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE dto_playlist; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.dto_playlist TO admin;


--
-- TOC entry 3085 (class 0 OID 0)
-- Dependencies: 208
-- Name: SEQUENCE song_song_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.song_song_id_seq TO admin;


--
-- TOC entry 3086 (class 0 OID 0)
-- Dependencies: 209
-- Name: TABLE song; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.song TO admin;
GRANT SELECT ON TABLE public.song TO performer;


--
-- TOC entry 3087 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE dto_song; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.dto_song TO admin;


--
-- TOC entry 3088 (class 0 OID 0)
-- Dependencies: 212
-- Name: TABLE song_playlist_relship; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.song_playlist_relship TO admin;


--
-- TOC entry 3089 (class 0 OID 0)
-- Dependencies: 213
-- Name: TABLE users_liked_performer; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users_liked_performer TO admin;


--
-- TOC entry 3090 (class 0 OID 0)
-- Dependencies: 214
-- Name: TABLE users_playlist_relship; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users_playlist_relship TO admin;


-- Completed on 2022-12-21 08:27:10

--
-- PostgreSQL database dump complete
--

