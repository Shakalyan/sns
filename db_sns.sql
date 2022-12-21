--
-- PostgreSQL database dump
--

-- Dumped from database version 12.12
-- Dumped by pg_dump version 12.12

-- Started on 2022-12-21 05:40:40

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
-- TOC entry 288 (class 1255 OID 42302)
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
-- TOC entry 286 (class 1255 OID 42089)
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
-- TOC entry 278 (class 1255 OID 49832)
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
-- TOC entry 280 (class 1255 OID 42071)
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
	IF check_injections(username) OR check_injections(user_password) OR 
	check_injections(email) OR check_injections(phone) THEN
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
-- TOC entry 279 (class 1255 OID 42091)
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
-- TOC entry 287 (class 1255 OID 42090)
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
-- TOC entry 277 (class 1255 OID 42067)
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
-- TOC entry 282 (class 1255 OID 42069)
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
-- TOC entry 283 (class 1255 OID 42077)
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
-- TOC entry 284 (class 1255 OID 42075)
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
-- TOC entry 276 (class 1255 OID 42074)
-- Name: show_performer_albums(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.show_performer_albums(id_perf bigint) RETURNS TABLE(id_album bigint, album_name character varying, creator_id bigint, songs_count integer, cover_url character varying, id_performer bigint, performer_name character varying, followers bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	IF check_injections(format('%s', id_perf)) THEN
    RAISE EXCEPTION 'Probably injections';
    END IF;	
	RETURN QUERY SELECT dto_album.album_id, dto_album.album_name, dto_album.creator_id, 
	dto_album.songs_count, dto_album.cover_url, dto_album.creator_id, 
	dto_album.username, dto_album.followers FROM dto_album WHERE id_perf = dto_album.creator_id;
END;
$$;


ALTER FUNCTION public.show_performer_albums(id_perf bigint) OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 42078)
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
3	0
\.


--
-- TOC entry 3011 (class 0 OID 42016)
-- Dependencies: 211
-- Data for Name: playlist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.playlist (playlist_id, playlist_name, cover_url, creator_id, songs_count) FROM stdin;
3	Favourite Songs	data/cover_favouritePlaylist/favouritePlaylist.png	3	0
6	some	data/3/playlists/6/img.png	3	0
4	zalupa	data/3/playlists/4/img.png	3	0
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
3	test	37268335dd6931045bdcdf92623ff819a64244b53d0e746d438797349d4da578	test	test	data/3/img.png
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

SELECT pg_catalog.setval('public.playlist_playlist_id_seq', 7, true);


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

SELECT pg_catalog.setval('public.users_user_id_seq', 3, true);


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
-- TOC entry 2833 (class 1259 OID 42189)
-- Name: album_name_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX album_name_index ON public.album USING gin (lower((album_name)::text) public.gin_trgm_ops);


--
-- TOC entry 2837 (class 1259 OID 42190)
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
-- TOC entry 2822 (class 1259 OID 42188)
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
-- Dependencies: 288
-- Name: PROCEDURE add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON PROCEDURE public.add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE public.add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying) TO performer;
GRANT ALL ON PROCEDURE public.add_song_in_album(_user_id bigint, _album_id bigint, _song_name character varying) TO admin;


--
-- TOC entry 3026 (class 0 OID 0)
-- Dependencies: 286
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
-- Dependencies: 280
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
-- Dependencies: 279
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
-- Dependencies: 287
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
-- Dependencies: 277
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
-- Dependencies: 282
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
-- Dependencies: 283
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
-- Dependencies: 284
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
-- Dependencies: 276
-- Name: FUNCTION show_performer_albums(id_perf bigint); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.show_performer_albums(id_perf bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.show_performer_albums(id_perf bigint) TO admin;
GRANT ALL ON FUNCTION public.show_performer_albums(id_perf bigint) TO performer;
GRANT ALL ON FUNCTION public.show_performer_albums(id_perf bigint) TO listener;


--
-- TOC entry 3059 (class 0 OID 0)
-- Dependencies: 285
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


-- Completed on 2022-12-21 05:40:40

--
-- PostgreSQL database dump complete
--

