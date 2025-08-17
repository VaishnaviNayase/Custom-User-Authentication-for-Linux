CREATE TABLE users(
	user_id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
	username text UNIQUE,
	password text 
);

CREATE TABLE groups(
	group_id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
	group_name text UNIQUE
);

CREATE TABLE groupmember(
	group_id uuid,
	user_id uuid,
	PRIMARY KEY(group_id,user_id),
	FOREIGN KEY(group_id) REFERENCES groups(group_id) ON DELETE CASCADE,
	FOREIGN KEY(user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE acl(
	user_id uuid,
	group_id uuid,
	object_type boolean,
	parent uuid,
	file_id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
	file_name text, 
	permissions smallint,
	FOREIGN KEY(group_id) REFERENCES groups(group_id) ON DELETE CASCADE,
	FOREIGN KEY(parent) REFERENCES acl(file_id) ON DELETE CASCADE,
	FOREIGN KEY(user_id) REFERENCES users(user_id) ON DELETE CASCADE 
);
create type error_tuple as(e1 boolean, e2 varchar(50));
--create type array as(a1 boolean, a2 uuid[]);

CREATE OR REPLACE FUNCTION create_user(curent_user text, new_user_name text, new_user_pasword text) RETURNS error_tuple AS $$
DECLARE
    output error_tuple;
BEGIN
    IF curent_user = 'root' THEN
        IF EXISTS (SELECT 1 FROM users WHERE username = new_user_name) THEN
            output := (false, 'User already exists!');
        ELSE
            INSERT INTO users(username, password)
            VALUES (new_user_name, md5(new_user_pasword));
            output := (true, 'User Created!');
        END IF;
    ELSE
        output := (false, 'Permission Denied!');
    END IF;

    RETURN output;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_user(curent_user text,user_to_change text,old_password text,new_password text) RETURNS error_tuple AS $$
DECLARE
	output error_tuple;
BEGIN
	if current_user = 'root' or curent_user = user_to_change then
		if exists (select username from users where username = user_to_change) then
			update users set password = new_password where username = user_to_change;
			output := (true,'User Changed!');
		else
			output := (false,'User does not exist!');
		end if;
	else
		output := (false,'Permission Denied!');
	end if;
	return output;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_user(curent_user text,user_to_delete text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
BEGIN
	if curent_user = 'root' then
		if exists (select username from users where username = user_to_delete) then
			delete from users where username = user_to_delete;
			output := (true,'User Deleted!');
		else
			output := (false,'User does not exist!');
		end if;
	else
		output := (false,'Permission Denied!');
	end if;
	return output;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION create_group(curent_user text, grp_name text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
BEGIN
	if curent_user = 'root' then
                if not exists (select 1 from groups g where g.group_name = grp_name) then
                        insert into groups(group_name) values(grp_name);
		       	output := (true,'Group Created!');
                else
                        output := (false,'Group already exists!');
                end if;
        else
                output := (false,'Permission Denied!');
        end if;
	return output;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION add_to_group(curent_user text, grp_name text, user_name text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
u_id uuid;
g_id uuid;
BEGIN
	 if curent_user = 'root' then
                u_id := (select user_id from users where username = user_name);
		g_id := (select g.group_id from groups g where g.group_name = grp_name);
		if u_id is not null then
			if g_id is not null then
				if not exists (select 1 from groupmember g where g.group_id = g_id and g.user_id = u_id) then
                        		insert into groupmember(group_id,user_id) values(g_id,u_id);
                        		output := (true,'User added to group!');
                		else
                        		output := (false,'User already exists in group!');
				end if;
			else
                        	output := (false,'Group does not exists!');
			end if;
		else
                      	output := (false,'User does not exists!');
                end if;
        else
                output := (false,'Permission Denied!');
        end if;
        return output;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION move_out_of_group(curent_user text, grp_name text, user_name text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
u_id uuid;
g_id uuid;
BEGIN
	if curent_user = 'root' then
                u_id := (select user_id from users where username = user_name);
                g_id := (select g.group_id from groups g where g.group_name = grp_name);
                if u_id is not null then
                        if g_id is not null then
                                if exists (select 1 from groupmember g where g.group_id = g_id and g.user_id = u_id) then
                                        delete from groupmember where group_id = g_id and user_id = u_id;
                                        output := (true,'User deleted from group!');
                                else
                                        output := (false,'User does not exist in group!');
                                end if;
                        else
                                output := (false,'Group does not exists!');
                        end if;
                else
                        output := (false,'User does not exists!');
                end if;
        else
                output := (false,'Permission Denied!');
        end if;
        return output;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_group(curent_user text, grp_name text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
BEGIN
	if curent_user = 'root' then
                if exists (select 1 from groups g where g.group_name = grp_name) then
                        delete from groups where group_name = grp_name ;
                        output := (true,'Group Deleted!');
                else
                        output := (false,'Group does not exist!');
                end if;
        else
                output := (false,'Permission Denied!');
        end if;
        return output;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION path_array(pathname text) RETURNS uuid[] AS $$
DECLARE
output uuid[];
prent uuid;
fdpath text[];
current_fid uuid;
BEGIN
	if pathname = '/' then 
		output := array_append(output,(select file_id from acl where file_name = '/'));
	else
		select  string_to_array(pathname,'/') into fdpath;
		if fdpath[1] = '' then
			select file_id into prent from acl where file_name = '/';
			output := array_append(output, prent); 
			FOR i IN 2 .. array_upper(fdpath, 1)  
			LOOP
				select file_id into current_fid from acl where file_name = fdpath[i] and parent = prent and object_type = true;
				if current_fid is not null  then
					output := array_append(output,current_fid);
					prent := current_fid;
				else
					output := null;
					exit;
				end if;	
			END LOOP;
		else
			output := null;
		end if;	
	end if;
	return output;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_file(curent_user text,object_type boolean,pathname text,f_name text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
op uuid[];
flag boolean; 
perm smallint;
BEGIN
	flag := false;
	op := (select path_array(pathname));
	if op is null then
		output := (false,'Not a valid path!');
	else
		if object_type = true  then
			perm = 509;
		else
			perm = 436;
		end if;
		if curent_user = 'root' then 
			insert into acl (user_id,group_id,object_type,file_name,permissions,parent) values((select user_id from users where username = 'root'),null,object_type,f_name,perm,op[array_upper(op,1)]);
			output := (true, 'Object created!');
		else
			if exists (select 1 from acl where file_name = f_name and parent = op[array_upper(op,1)]) then
				output := (false, 'Object already exists!');
			else
				FOR i IN 1 .. array_upper(op, 1)  
   				LOOP
					if not exists (select 1 from acl where file_id = op[i] and ((permissions & 192) = 192  or ((select user_id from users where username=curent_user) != (select user_id from acl where file_id = op[i]) and (permissions & 3) = 3) or (group_id is not null and (permissions & 24) = 24 and user_id != (select user_id from users where username = curent_user) and ((select user_id from users where username=curent_user) in (select user_id from groupmember where group_id = (select group_id from acl where file_id=op[i])))))) then  	  
						output := (false, 'Permission Denied');
						flag := true;
						exit;
					end if;
				end LOOP;
				if flag = false then
					insert into acl (user_id,group_id,object_type,file_name,permissions,parent) values((select user_id from users where username = curent_user),null,object_type,f_name,perm,op[array_upper(op,1)]);
					output := (true, 'Object Created!');
				end if;
			end if;
		end if;
	end if;	
	return output;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_file(curent_user text,object_type boolean,pathname text,f_name text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
op uuid[];
flag boolean; 
BEGIN
	flag := false;
	op := (select path_array(pathname));
	if op is null then
		output := (false,'Not a valid path!');
	else
		if curent_user = 'root' then 
			delete from acl where file_name = f_name and parent = op[array_upper(op,1)];
			output := (true, 'Object deleted!');
		else
			if not exists (select 1 from acl where file_name = f_name and parent = op[array_upper(op,1)]) then
				output := (false, 'Object does not exist!');
			else
				FOR i IN 1 .. array_upper(op, 1)  
   				LOOP
					if not exists (select 1 from acl where file_id = op[i] and ((permissions & 192) = 192  or ((select user_id from users where username=curent_user) != (select user_id from acl where file_id = op[i]) and (permissions & 3) = 3) or (group_id is not null and (permissions & 24) = 24 and user_id != (select user_id from users where username = curent_user) and ((select user_id from users where username=curent_user) in (select user_id from groupmember where group_id = (select group_id from acl where file_id=op[i])))))) then  	  
						output := (false, 'Permission Denied');
						flag := true;
						exit;
					end if;
				end LOOP;
				if flag = false then
					delete from acl where file_name = f_name and parent = op[array_upper(op,1)];
					output := (true, 'Object Deleted!');
				end if;
			end if;
		end if;
	end if;	
	return output;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION change_file_owner(curent_user text, user_name text, file_path text, f_name text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
op uuid[];
BEGIN	
	if curent_user = 'root' then
                if exists (select 1 from users where username = user_name) then
			op :=(select path_array(pathname));
			if exists (select 1 from acl where file_name = f_name and parent = op[array_upper(op,1)]) then 

				update acl set user_id = (select user_id from users where username = user_name) where file_name = f_name and parent = op[array_upper(op,1)];
		       		output := (true,'Owner Changed!');
			else
				output := (false,'Object does not exist!');
			end if;
                else
                        output := (false,'User does not exits!');
                end if;
        else
                output := (false,'Permission Denied!');
        end if;
	return output;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_permissions(pathname text, f_name text) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
op uuid[];
BEGIN
	op :=(select path_array(pathname));
	if exists (select 1 from acl where file_name = f_name and parent = op[array_upper(op,1)]) then 
		output := (true, (select permissions from acl where file_name = f_name and parent = op[array_upper(op,1)])::int::bit(9)::text);
	else
		output := (false,'Object does not exist!');
        end if;
	return output;	
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_permissions(curent_user text, pathname text, f_name text, new_permissions smallint) RETURNS error_tuple AS $$
DECLARE
output error_tuple;
op uuid[];
BEGIN
	op :=(select path_array(pathname));
	if curent_user = 'root' or (select user_id from users where username = curent_user) = (select user_id from acl where file_name = f_name and parent = op[array_upper(op,1)])  then
		if exists (select 1 from acl where file_name = f_name and parent = op[array_upper(op,1)]) then 
			update acl set permissions = new_permissions where file_name = f_name and parent = op[array_upper(op,1)];
		       		output := (true,'Permissions Changed!');
		else
				output := (false,'Object does not exist!');
                end if;
        else
                output := (false,'Permission Denied!');
        end if;
	return output;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION change_file_group(curent_user text, grp_name text,pathname text,f_name text) RETURNS error_tuple AS $$
DECLARE
op uuid[];
output error_tuple;
BEGIN
	op := (select path_array(pathname));
  	if curent_user = 'root' or exists (select 1 from acl where file_name = f_name and parent = op[array_upper(op,1)] and user_id = (select user_id from users where username = curent_user)) then
        	if exists (select 1 from groups where group_name = grp_name) then
      		update acl  set group_id = (select group_id from groups where group_name = grp_name) where file_name = f_name and parent = op[array_upper(op,1)];
      		output := (true,'Object group changed!');
    		else
      			output := (false,'Group does not exist!');
    		end if;
  	else
    		output := (false,'Permission Denied!');
  	end if;
  	return output;
END;
$$ LANGUAGE plpgsql;


select * from create_user('root','root','1234r');
select * from create_group('root','sudo');
insert into acl (user_id,group_id,object_type,file_name,permissions) values((select user_id from users where username = 'root'),null,true,'/',508);
