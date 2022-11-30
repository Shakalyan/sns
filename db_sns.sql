PGDMP                     
    z            DB_SNUS    12.12    12.12 )    @           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            A           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            B           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            C           1262    16863    DB_SNUS    DATABASE     �   CREATE DATABASE "DB_SNUS" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'Russian_Russia.1251' LC_CTYPE = 'Russian_Russia.1251';
    DROP DATABASE "DB_SNUS";
                postgres    false            �            1255    16877 0   check_user(character varying, character varying)    FUNCTION     �  CREATE FUNCTION public.check_user(check_username character varying, check_user_password character varying) RETURNS text
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
 j   DROP FUNCTION public.check_user(check_username character varying, check_user_password character varying);
       public          postgres    false            �            1255    16873 W   create_user(character varying, character varying, character varying, character varying)    FUNCTION     �  CREATE FUNCTION public.create_user(username character varying, user_password character varying, email character varying, phone_number character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	INSERT INTO users(username, user_password, email, phone_number) 
		VALUES (username, user_password, email, phone_number);
END;
$$;
 �   DROP FUNCTION public.create_user(username character varying, user_password character varying, email character varying, phone_number character varying);
       public          postgres    false            �            1255    17006    show_songs_playlist(bigint)    FUNCTION     o  CREATE FUNCTION public.show_songs_playlist(_id_playlist bigint) RETURNS TABLE(id_song bigint, song_name character varying, creator_name character varying, song_link character varying, duration smallint, song_text text, id_album bigint)
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
 ?   DROP FUNCTION public.show_songs_playlist(_id_playlist bigint);
       public          postgres    false            �            1255    17005 %   show_user_playlist(character varying)    FUNCTION       CREATE FUNCTION public.show_user_playlist(_username character varying) RETURNS TABLE(id_playlist bigint, playlist_name character varying, music_count integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN 
	RETURN QUERY SELECT playlist.id_playlist, playlist.playlist_name, playlist.music_count FROM playlist 
	INNER JOIN users_playlist_relship ON users_playlist_relship.id_playlist = playlist.id_playlist 
	AND users_playlist_relship.username = _username;
END;
$$;
 F   DROP FUNCTION public.show_user_playlist(_username character varying);
       public          postgres    false            �            1259    16931    album    TABLE     �   CREATE TABLE public.album (
    id_album bigint NOT NULL,
    album_name character varying(50) NOT NULL,
    creator_name character varying(50) NOT NULL
);
    DROP TABLE public.album;
       public         heap    postgres    false            �            1259    16925 	   performer    TABLE     �   CREATE TABLE public.performer (
    performer_name character varying(50) NOT NULL,
    followers_count bigint DEFAULT 0 NOT NULL
);
    DROP TABLE public.performer;
       public         heap    postgres    false            �            1259    16977    performer_users_relship    TABLE     �   CREATE TABLE public.performer_users_relship (
    performer_name character varying(50) NOT NULL,
    username character varying(50) NOT NULL
);
 +   DROP TABLE public.performer_users_relship;
       public         heap    postgres    false            �            1259    16941    playlist    TABLE     �   CREATE TABLE public.playlist (
    id_playlist bigint NOT NULL,
    playlist_name character varying(50) NOT NULL,
    music_count integer NOT NULL
);
    DROP TABLE public.playlist;
       public         heap    postgres    false            �            1259    16946    song    TABLE       CREATE TABLE public.song (
    id_song bigint NOT NULL,
    song_name character varying(50) NOT NULL,
    creator_name character varying(50) NOT NULL,
    song_link character varying(200) NOT NULL,
    duration smallint NOT NULL,
    song_text text,
    id_album bigint
);
    DROP TABLE public.song;
       public         heap    postgres    false            �            1259    16964    song_playlist_relship    TABLE     l   CREATE TABLE public.song_playlist_relship (
    id_song bigint NOT NULL,
    id_playlist bigint NOT NULL
);
 )   DROP TABLE public.song_playlist_relship;
       public         heap    postgres    false            �            1259    16864    users    TABLE     �   CREATE TABLE public.users (
    username character varying(50) NOT NULL,
    user_password character varying(50),
    email character varying(50),
    phone_number character varying(15)
);
    DROP TABLE public.users;
       public         heap    postgres    false            �            1259    16990    users_playlist_relship    TABLE     }   CREATE TABLE public.users_playlist_relship (
    username character varying(50) NOT NULL,
    id_playlist bigint NOT NULL
);
 *   DROP TABLE public.users_playlist_relship;
       public         heap    postgres    false            8          0    16931    album 
   TABLE DATA                 public          postgres    false    204   8       7          0    16925 	   performer 
   TABLE DATA                 public          postgres    false    203   �8       <          0    16977    performer_users_relship 
   TABLE DATA                 public          postgres    false    208   �8       9          0    16941    playlist 
   TABLE DATA                 public          postgres    false    205   9       :          0    16946    song 
   TABLE DATA                 public          postgres    false    206   d9       ;          0    16964    song_playlist_relship 
   TABLE DATA                 public          postgres    false    207   :       6          0    16864    users 
   TABLE DATA                 public          postgres    false    202   k:       =          0    16990    users_playlist_relship 
   TABLE DATA                 public          postgres    false    209   ;       �
           2606    16935    album album_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_pkey PRIMARY KEY (id_album);
 :   ALTER TABLE ONLY public.album DROP CONSTRAINT album_pkey;
       public            postgres    false    204            �
           2606    16930    performer performer_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.performer
    ADD CONSTRAINT performer_pkey PRIMARY KEY (performer_name);
 B   ALTER TABLE ONLY public.performer DROP CONSTRAINT performer_pkey;
       public            postgres    false    203            �
           2606    16945    playlist playlist_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.playlist
    ADD CONSTRAINT playlist_pkey PRIMARY KEY (id_playlist);
 @   ALTER TABLE ONLY public.playlist DROP CONSTRAINT playlist_pkey;
       public            postgres    false    205            �
           2606    16953    song song_pkey 
   CONSTRAINT     Q   ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_pkey PRIMARY KEY (id_song);
 8   ALTER TABLE ONLY public.song DROP CONSTRAINT song_pkey;
       public            postgres    false    206            �
           2606    17008 A   performer_users_relship username_unique_in_relship_with_performer 
   CONSTRAINT     �   ALTER TABLE ONLY public.performer_users_relship
    ADD CONSTRAINT username_unique_in_relship_with_performer UNIQUE (username);
 k   ALTER TABLE ONLY public.performer_users_relship DROP CONSTRAINT username_unique_in_relship_with_performer;
       public            postgres    false    208            �
           2606    16870    users users_email_key 
   CONSTRAINT     Q   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);
 ?   ALTER TABLE ONLY public.users DROP CONSTRAINT users_email_key;
       public            postgres    false    202            �
           2606    16872    users users_phone_number_key 
   CONSTRAINT     _   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_number_key UNIQUE (phone_number);
 F   ALTER TABLE ONLY public.users DROP CONSTRAINT users_phone_number_key;
       public            postgres    false    202            �
           2606    16868    users users_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (username);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public            postgres    false    202            �
           2606    16936    album album_creator_name_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.album
    ADD CONSTRAINT album_creator_name_fkey FOREIGN KEY (creator_name) REFERENCES public.performer(performer_name);
 G   ALTER TABLE ONLY public.album DROP CONSTRAINT album_creator_name_fkey;
       public          postgres    false    2726    204    203            �
           2606    16980 C   performer_users_relship performer_users_relship_performer_name_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.performer_users_relship
    ADD CONSTRAINT performer_users_relship_performer_name_fkey FOREIGN KEY (performer_name) REFERENCES public.performer(performer_name);
 m   ALTER TABLE ONLY public.performer_users_relship DROP CONSTRAINT performer_users_relship_performer_name_fkey;
       public          postgres    false    2726    208    203            �
           2606    16985 =   performer_users_relship performer_users_relship_username_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.performer_users_relship
    ADD CONSTRAINT performer_users_relship_username_fkey FOREIGN KEY (username) REFERENCES public.users(username);
 g   ALTER TABLE ONLY public.performer_users_relship DROP CONSTRAINT performer_users_relship_username_fkey;
       public          postgres    false    202    2724    208            �
           2606    16954    song song_creator_name_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_creator_name_fkey FOREIGN KEY (creator_name) REFERENCES public.performer(performer_name);
 E   ALTER TABLE ONLY public.song DROP CONSTRAINT song_creator_name_fkey;
       public          postgres    false    203    2726    206            �
           2606    16959    song song_id_album_fkey    FK CONSTRAINT     }   ALTER TABLE ONLY public.song
    ADD CONSTRAINT song_id_album_fkey FOREIGN KEY (id_album) REFERENCES public.album(id_album);
 A   ALTER TABLE ONLY public.song DROP CONSTRAINT song_id_album_fkey;
       public          postgres    false    206    204    2728            �
           2606    16972 <   song_playlist_relship song_playlist_relship_id_playlist_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.song_playlist_relship
    ADD CONSTRAINT song_playlist_relship_id_playlist_fkey FOREIGN KEY (id_playlist) REFERENCES public.playlist(id_playlist);
 f   ALTER TABLE ONLY public.song_playlist_relship DROP CONSTRAINT song_playlist_relship_id_playlist_fkey;
       public          postgres    false    205    2730    207            �
           2606    16967 8   song_playlist_relship song_playlist_relship_id_song_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.song_playlist_relship
    ADD CONSTRAINT song_playlist_relship_id_song_fkey FOREIGN KEY (id_song) REFERENCES public.song(id_song);
 b   ALTER TABLE ONLY public.song_playlist_relship DROP CONSTRAINT song_playlist_relship_id_song_fkey;
       public          postgres    false    2732    207    206            �
           2606    16998 >   users_playlist_relship users_playlist_relship_id_playlist_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_playlist_relship
    ADD CONSTRAINT users_playlist_relship_id_playlist_fkey FOREIGN KEY (id_playlist) REFERENCES public.playlist(id_playlist);
 h   ALTER TABLE ONLY public.users_playlist_relship DROP CONSTRAINT users_playlist_relship_id_playlist_fkey;
       public          postgres    false    205    2730    209            �
           2606    16993 ;   users_playlist_relship users_playlist_relship_username_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_playlist_relship
    ADD CONSTRAINT users_playlist_relship_username_fkey FOREIGN KEY (username) REFERENCES public.users(username);
 e   ALTER TABLE ONLY public.users_playlist_relship DROP CONSTRAINT users_playlist_relship_username_fkey;
       public          postgres    false    2724    209    202            8   [   x���v
Q���W((M��L�K�I*�Us�	uV�0�QP�0�b����.l��C���.칰��ދ��@YǼ������*uMk... B�!�      7   P   x���v
Q���W((M��L�+H-J�/�M-Rs�	uV�P��ϬJU�MV�Q04� Mk.O��:�%&��$V�j�� �#�      <   
   x���          9   P   x���v
Q���W((M��L�+�I���,.Qs�	uV�0�QP���NMQ(��K/V�Q0д��$B�Pg��OT �m <      :   �   x���v
Q���W((M��L�+��KWs�	uV�0�QP�0�¦.�_�ua�:�Y����b���TYF:
~�>>RӚ˓��F �^�4����{/�[��}[/6\�pa���;A�8�%&��$V��i��h! >QM      ;   O   x���v
Q���W((M��L�+��K�/�I���,.�/J�)��,Ps�	uV�0�Q0Դ��$U������g��� �H�      6   �   x���v
Q���W((M��L�+-N-*Vs�	uV�P�M,N��OS�QPOL���1r���3�RRS�r3s�JA��f�Ɩf&����\����ϬJU�Mk6735161��AX�8�����R�@�@��`��bF ø� ��B      =   \   x���v
Q���W((M��L�+-N-*�/�I���,.�/J�)��,Ps�	uV�P�M,N��OS�Q0Դ��� #���ϬJU�M�:�� �@�     