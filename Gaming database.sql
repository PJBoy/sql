SET time_zone = "+00:00";

CREATE DATABASE `Buffalo` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
USE `Buffalo`;

DELIMITER $$
CREATE PROCEDURE `best_match`(IN `username_in` TEXT)
BEGIN
    SET @userID := (SELECT ID FROM user WHERE user.username = username_in);
    SELECT username, commFrNo as Common_friends, comGameNo as Common_games
    FROM user,
    (
        SELECT
            t100.suggestionFr,
            commFrNo + comGameNo as commC,
            commFrNo, comGameNo
        FROM
            (
                SELECT
                    user_id as suggestionFr,
                    game_id as commonGame,
                    COUNT(*) as comGameNo
                FROM ownership
                WHERE
                    game_id IN (SELECT game_id FROM ownership WHERE user_id LIKE @userID) AND
                    user_id <> @userID
                GROUP BY user_id
            ) t100,
            (
                SELECT
                    suggestionFr,
                    SUM(commFrNo) as commFrNo
                FROM
                    (
                            SELECT
                                friend1 as suggestionFr,
                                friend2 as commonFr,
                                COUNT(*) as commFrNo
                            FROM friendship
                            WHERE
                                friend1 IN (SELECT friend1 FROM friendship WHERE friend2 LIKE @userID) AND
                                friend2 <> @userID
                            GROUP BY friend1
                        UNION
                            SELECT
                                friend1 as suggestionFr,
                                friend2 as commonFr,
                                COUNT(*) as commFrNo
                            FROM friendship
                            WHERE
                                friend1 IN (SELECT friend2 FROM friendship WHERE friend1 LIKE @userID) AND
                                friend2 <> @userID
                            GROUP BY friend1
                        UNION
                            SELECT
                                friend2 as suggestionFr,
                                friend1 as commonFr,
                                COUNT(*) as commFrNo
                            FROM friendship
                            WHERE
                                friend2 IN (SELECT friend2 FROM friendship WHERE friend1 LIKE @userID) AND
                                friend1 <> @userID
                            GROUP BY friend2
                        UNION
                            SELECT
                                friend2 as suggestionFr,
                                friend1 as commonFr,
                                COUNT(*) as commFrNo
                            FROM friendship
                            WHERE
                                friend2 IN (SELECT friend1 FROM friendship WHERE friend2 LIKE @userID) AND
                                friend1 <> @userID
                            GROUP BY friend2
                    ) t1
                GROUP BY suggestionFr
            ) t101
        WHERE t100.suggestionFr = t101.SuggestionFr
        ORDER BY
            commC DESC,
            commFrNo DESC
        LIMIT 1
    ) BFF
    WHERE BFF.suggestionFr = user.ID;
END$$

CREATE PROCEDURE `display_friends`(IN `username_in` TEXT)
    SELECT username
    FROM user
    WHERE
        id IN
            (
                SELECT friend1
                FROM friendship
                WHERE
                    friend2 = (SELECT ID FROM user WHERE username=username_in) AND
                    response = 1
            ) OR
        id IN
            (
                SELECT friend2
                FROM friendship
                WHERE
                    friend1 = (SELECT ID FROM user WHERE username=username_in) AND
                    response = 1
            )$$

CREATE PROCEDURE `get_user_game_achievements`
(
    IN `userNameIn` TEXT,
    IN `gameName` TEXT
)
BEGIN
    SET
        @userID := (SELECT ID FROM user WHERE username = userNameIn),
        @gameID := (SELECT ID FROM game WHERE name = gameName);
        (
            SELECT
                title,
                point_value AS points,
                descr_after AS description,
                date AS achieved_on
            FROM
                (
                    SELECT *
                    FROM
                        (
                            SELECT *
                            FROM achievement
                            WHERE game_id=@gameID
                        ) q0,
                        user_achievement
                    WHERE
                        user_achievement.user_id=@userID AND
                        user_achievement.achievement_id=ID
                ) q1
        )
    UNION
        (
            SELECT
                title,
                point_value AS points,
                descr_before AS description,
                NULL AS achieved_on
            FROM achievement
            WHERE
                game_id=@gameID AND
                hidden=0 AND
                NOT EXISTS
                    (
                        SELECT *
                        FROM user_achievement
                        WHERE
                            user_id=@userID AND
                            achievement_id=ID
                    )
        );
END$$

CREATE PROCEDURE `insert_achievement`
(
    IN `title_in` TEXT,
    IN `gameName` TEXT,
    IN `pointValue` INT,
    IN `hidden` TINYINT,
    IN `descriptionBefore` VARCHAR(2000),
    IN `descriptionAfter` VARCHAR(2000),
    OUT `ID_out` INT
)
BEGIN
	SET @gameID := (SELECT ID FROM game WHERE name=gameName);
    INSERT INTO achievement (title, game_id, point_value, hidden, descr_before, descr_after)
    VALUES (title_in, @gameID, pointValue, hidden, descriptionBefore, descriptionAfter);
    SET ID_out = (
        SELECT ID
        FROM achievement
        WHERE
            title=title_in AND
            game_id=@gameID
    );
END$$

CREATE PROCEDURE `insert_game`
(
    IN `name_IN` TEXT,
    IN `description_IN` TEXT,
    IN `version` TEXT,
    IN `age_rating` INT,
    IN `url` TEXT,
    IN `publisherName` TEXT,
    IN `maxScore` INT,
    IN `minScore` INT,
    IN `scoreSortOrder` BOOLEAN,
    IN `scoreFormat` VARCHAR(255),
    OUT `ID_out` INT
)
BEGIN
	SET @publisherID = (SELECT ID FROM publisher WHERE Name LIKE publisherName);
    INSERT INTO game (name, description, version, age_rating, url, publisher_id, maximum_score, minimum_score, sort_order, score_format)
	VALUES (name_IN, description_IN, version, age_rating, url, @publisherID, maxScore, minScore, scoreSortOrder, scoreFormat);
	SET ID_out = (SELECT ID FROM game WHERE name=name_IN AND description=description_IN LIMIT 1);
END$$

CREATE PROCEDURE `insert_ownership`
(
    IN `userName_in` TEXT,
    IN `gameName_in` TEXT,
    IN `rating` FLOAT,
    IN `comment` TEXT,
    IN `notification` TINYINT
)
BEGIN
	SET @userID = (SELECT ID FROM user WHERE username=userName_in);
    SET @gameID = (SELECT ID FROM game WHERE name=gameName_in);
    SET @version = (SELECT version FROM game WHERE ID=@gameID);
    INSERT INTO ownership(user_id, game_id, rating, comment, version, notification)
    VALUES (@userID, @gameID, rating, comment, @version, notification);
END$$

CREATE PROCEDURE `insert_user`
(
    IN `username_in` VARCHAR(255),
    IN `firstName` TEXT,
    IN `lastName` TEXT,
    IN `email` VARCHAR(255),
    IN `password` TEXT,
    IN `status` TEXT,
    OUT `ID_out` INT
)
BEGIN
	INSERT INTO user(username, first_name, second_name, email, password, status)
    VALUES (username_in, firstName, lastName, email, password, status);
    set ID_out = (SELECT ID FROM user WHERE username=username_in);
END$$

CREATE PROCEDURE `leaderboard_friends`
(
    IN `username_in` VARCHAR(255),
    IN `game_in` VARCHAR(255)
)
BEGIN
	SET @userID := (select ID from user where username = username_in),
		@gameID := (select ID from game where name = game_in),
        @prefix := (
            select prefix
            from
                score_format,
                game
            where
                game.score_format = score_format.id and
                game.id = @gameID
        ),
        @suffix := (
            select suffix
            from
                score_format,
                game
            where
                game.score_format = score_format.id and
                game.id = @gameID
        );
    if (select sort_order from game where id=@gameID) = 0 then
        SELECT
            username,
            high_score AS 'High Score'
        FROM
            ownership,
            user
        WHERE
            game_id=@gameID AND
            (
                user_id IN
                (
                    SELECT friend1
                    FROM friendship
                    WHERE
                        friend2=@userID AND
                        response=1
                ) OR
                user_id IN
                (
                    SELECT friend2
                    FROM friendship
                    WHERE
                        friend1=@userID AND
                        response=1
                ) OR
                user_id=@userID
            ) AND
            ownership.user_id = user.ID
        ORDER BY high_score DESC;
    else
        SELECT
            username,
            high_score AS 'High Score'
        FROM
            ownership,
            user
        WHERE
            game_id=@gameID AND
            (
                user_id IN
                (
                    SELECT friend1
                    FROM friendship
                    WHERE
                        friend2=@userID AND
                        response=1
                ) OR
                user_id IN
                (
                    SELECT friend2
                    FROM friendship
                    WHERE
                        friend1=@userID AND
                        response=1
                ) OR
                user_id=@userID
            ) AND
            ownership.user_id = user.ID
        ORDER BY high_score;
    end if;
END$$

CREATE PROCEDURE `list_friends`(IN `user_in` VARCHAR(255))
BEGIN
	SET @userID := (SELECT ID FROM user WHERE username=user_in);
        (
            select
                username,
                logged_in,
                last_logged_in,
                (
                    select game.name
                    from
                        game,
                        ownership,
                        user
                    where
                        game.id=game_id and
                        user_id=@userID
                    order by last_played desc
                    limit 1
                ) as last_game_played
            from
                friendship,
                user
            where
                (
                        friend1=@userID and
                        user.id=friend2
                        and response=1
                    or
                        friend2=@userID and
                        user.id=friend1
                        and response=1
                ) and
                logged_in=0
        )
    union
        (
            select
                username,
                logged_in,
                NULL,
                (
                    select game.name
                    from
                        game,
                        ownership,
                        user
                    where
                        game.id=game_id and
                        user_id=@userID
                    order by last_played desc
                    limit 1
                ) as last_game_played
            from
                friendship,
                user
            where
            (
                    friend1=@userID and
                    user.id=friend2
                    and response=1
                or
                    friend2=@userID and
                    user.id=friend1
                    and response=1
            ) and
            logged_in=1
        );
END$$

CREATE PROCEDURE `list_game_owners`(IN `game_in` TEXT)
    select
        user.ID as ID,
        username
    from
        game,
        user,
        ownership
    where
        game.name=game_in and
        game.id=game_id and
        user_id=user.id
$$

CREATE PROCEDURE `player_status`
(
    IN `userID_in` INT,
    IN `userName_in` TEXT
)
BEGIN
	IF (userID_in=0)
    THEN
		SET @userID := (SELECT ID FROM user WHERE username=userName_in LIMIT 1);
    ELSE
    	SET @userID := userID_in;
    END IF;
    SET @username := (SELECT username FROM user WHERE ID=@userID);
    SET @status := (SELECT status FROM user WHERE ID=@userID);
    SET @gamesNo := (SELECT COUNT(*) FROM ownership WHERE user_id=@userID);
    SET @friendsNo := (
        SELECT COUNT(*)
        FROM friendship
        WHERE
            (
                friend1=@userID OR
                friend2=@userID
            ) AND
            response=1
    );
    SET @points := (
        SELECT SUM(point_value)
        FROM
            achievement,
            user_achievement
        WHERE
            user_achievement.achievement_id = achievement.ID AND
            user_achievement.user_id = @userID
    );
    SELECT
        @username AS Username,
        @status as "Status line",
        @gamesNo AS "No. of Games Owned",
        @points AS "Achievement points",
        @friendsNo AS "No of Friends";
END$$

CREATE PROCEDURE `send_friend_request`
(
    IN `fromUser` TEXT,
    IN `toUserName` TEXT,
    IN `toUserEmail` TEXT
)
BEGIN
    SET
        @fromID := (SELECT ID FROM user WHERE username=fromUser),
        @toID := (
            SELECT ID
            FROM user
            WHERE
                username=toUserName OR
                email=toUserEmail
        );
    IF @toID<>@fromID THEN
        BEGIN
            IF NOT EXISTS
                (
                    SELECT *
                    FROM friendship
                    WHERE
                        (
                            friend1=@toID AND
                            friend2=@fromID
                        ) OR
                        (
                            friend1=@fromID AND
                            friend2=@toID
                        )
                ) THEN
                INSERT INTO friendship VALUES (@fromID, @toID, NULL);
            ELSEIF EXISTS
                (
                    SELECT *
                    FROM friendship
                    WHERE
                        friend1=@toUser AND
                        friend2=@fromUser AND
                        response<>1
                )
            THEN
                UPDATE friendship
                SET response=1
                WHERE
                    friend1=@toUser AND
                    friend2=@fromUser;
            END IF;
        END;
    END IF;
END$$

CREATE PROCEDURE `send_game_invite`
(
    IN `fromUser` TEXT,
    IN `toUserName` TEXT,
    IN `toUserEmail` TEXT,
    IN `forGameName` TEXT
)
BEGIN
    SET
        @fromID := (SELECT ID FROM user WHERE username=fromUser),
        @toID := (
            SELECT ID
            FROM user
            WHERE
                username=toUserName OR
                email=toUserEmail
        ),
        @gameID := (SELECT ID FROM game WHERE name=forGameName);
    IF EXISTS
        (
            SELECT *
            FROM friendship
            WHERE response=1 AND
                (
                    (
                        friend1=@fromID AND
                        friend2=@toID
                    ) OR
                    (
                        friend2=@fromID AND
                        friend1=@toID
                    )
                )
        )
    THEN
        INSERT INTO game_invite VALUES (@fromID, @toID, @gameID);
    END IF;
END$$

CREATE PROCEDURE `show_friends_games_points`
(
    IN `friend1_in` TEXT,
    IN `friend2_in` TEXT
)
BEGIN
    set @friend1 = (select ID from user where username = friend1_in),
        @friend2 = (select ID from user where username = friend2_in);

    if
    (
        @friend1 <> @friend2 AND
        (
            EXISTS
            (
                SELECT *
                FROM friendship
                where
                    friend1=@friend1 AND
                    friend2=@friend2 AND
                    response=1
            ) OR
            EXISTS
            (
                SELECT *
                FROM friendship
                where friend1=@friend2 AND
                friend2=@friend1 AND
                response=1
            )
        )
    )
    THEN
        BEGIN
            SELECT *
            FROM
                    (
                        select
                            ttt.name,
                            sumPoints as totalPoints1
                        from
                            (
                                select
                                    game_id,
                                    sum(point_value) as sumPoints
                                from achievement
                                where
                                    game_id in (select game_id from ownership where user_id =@friend1) and
                                    ID in (select achievement_id from user_achievement where user_id =@friend1)
                                group by game_id
                            ) tt,
                            (
                                select
                                    ID,
                                    name
                                from game
                                where game.id in (select game_id from ownership where user_id =@friend1)
                            ) ttt
                        where ttt.id in (select game_id from user_achievement where user_id = @friend1)
                    ) f1
                LEFT JOIN
                    (
                        select
                            ttt.name,
                            sumPoints as totalPoints2
                        from
                            (
                                select
                                    game_id,
                                    sum(point_value) as sumPoints
                                from achievement
                                where
                                    game_id in (select game_id from ownership where user_id = @friend2) and
                                    ID in (select achievement_id from user_achievement where user_id = @friend2)
                                group by game_id
                            ) tt,
                            (
                                select
                                    ID,
                                    name
                                from game
                                where game.id in (select game_id from ownership where user_id = @friend2)
                            ) ttt
                        where ttt.id in (select game_id from user_achievement where user_id = @friend2)
                    ) f2
                    using(name)
            UNION
                SELECT
                    name,
                    totalPoints1,
                    totalPoints2
                FROM
                    (
                            SELECT *
                            FROM
                                (
                                    select
                                        ttt.name,
                                        sumPoints as totalPoints1
                                    from
                                        (
                                            select
                                                game_id,
                                                sum(point_value) as sumPoints
                                            from achievement
                                            where
                                                game_id in (select game_id from ownership where user_id = @friend1) and
                                                ID in (select achievement_id from user_achievement where user_id = @friend1)
                                            group by game_id
                                        ) tt,
                                        (
                                            select
                                                ID, name
                                            from game
                                            where game.id in (select game_id from ownership where user_id = @friend1)
                                        ) ttt
                                    where ttt.id in (select game_id from user_achievement where user_id = @friend1)
                                ) f1
                        RIGHT JOIN
                            (
                                select
                                    ttt.name,
                                    sumPoints as totalPoints2
                                from
                                    (
                                        select
                                            game_id,
                                            sum(point_value) as sumPoints
                                        from achievement
                                        where
                                            game_id in (select game_id from ownership where user_id = @friend2) and
                                            ID in (select achievement_id from user_achievement where user_id = @friend2)
                                        group by game_id
                                    ) tt,
                                    (
                                        select
                                            ID, name
                                        from game
                                        where game.id in (select game_id from ownership where user_id = @friend2)
                                    ) ttt
                                where ttt.id in (select game_id from user_achievement where user_id = @friend2)
                            ) f2
                            using(name)
                    ) swapped;
        END;
    END IF;
END$$

CREATE PROCEDURE `suggest_game`(IN `UserName_in` TEXT)
BEGIN
	SET @userID := (SELECT ID FROM user WHERE username = UserName_in);
    SELECT name as suggestedGame
    FROM
        (
            SELECT
                game_id,
                rating
            FROM ownership
            WHERE
                user_id = (
                    SELECT friend
                    FROM
                        (
                            SELECT
                                AVG(ABS(rating-friendRating)) AS coef,
                                friend,
                                COUNT(friend) AS number
                            FROM
                                (
                                    SELECT
                                        ownership.rating,
                                        t3.friendRating,
                                        t3.friend,
                                        t3.game_id
                                    FROM
                                        (
                                            SELECT
                                                ownership.rating AS friendRating,
                                                friend,
                                                game_id
                                            FROM
                                                (
                                                    SELECT friend
                                                    FROM
                                                        (
                                                            (
                                                                SELECT friend2 AS friend
                                                                FROM friendship
                                                                WHERE
                                                                    response=1 AND
                                                                    friend1=@userID
                                                            )
                                                        UNION
                                                            (
                                                                SELECT friend1 AS friend
                                                                FROM friendship
                                                                WHERE
                                                                    response=1 AND
                                                                    friend2=@userID
                                                            )
                                                         )tt
                                                 ) friendList,
                                                 ownership
                                            WHERE
                                                ownership.user_ID = friend AND
                                                rating IS NOT NULL AND
                                                game_id IN (SELECT game_id FROM ownership WHERE user_ID=@userID)
                                        ) t3,
                                        ownership
                                    WHERE
                                        t3.game_id = ownership.game_id AND
                                        ownership.user_id = @userID
                                ) t5
                            GROUP BY friend
                            ORDER BY
                                coef,
                                number DESC
                            LIMIT 1
                        ) t5
                ) AND
                game_id NOT IN (SELECT game_id from ownership WHERE user_id=@userID)
            ORDER BY rating DESC
            LIMIT 1
        ) t7,
        game
    WHERE ID = game_id;
END$$

CREATE PROCEDURE `view_achievements`
(
    IN `username_in` VARCHAR(255),
    IN `game_in` TEXT,
    OUT `result_out` TEXT
)
begin
    set
        @gameID := (select ID from game where name=game_in),
        @userID := (select ID from user where username=username_in),
        @total_out = (select count(*) from achievement where game_id = @gameID),
        @unlocked_out = (
            select count(*)
            from user_achievement
            where
                achievement_id in (select ID from achievement where game_id = @gameID) and
                user_id = @userID
        ),
        @points_out = (
            select sum(point_value)
            from achievement
            where
                ID in
                    (
                        select achievement_id
                        from user_achievement
                        where
                            achievement_id in (select ID from achievement where game_id = @gameID) and
                            user_id = @userID
                    )
        );
    if @points_out is NULL then
        set @points_out = 0;
    END IF;
    set result_out = concat
    (
        cast(@unlocked_out as char(255)),
        ' of ',
        cast(@total_out as char(255)),
        ' achievements (' ,
        cast(@points_out as char(255)),
        ' points)',
        ''
    );
end$$

CREATE PROCEDURE `view_leaderboard_entry`
(
    IN `username_in` VARCHAR(255),
    IN `game_in` TEXT,
    OUT `string_out` TEXT
)
begin
    set
        @gameID := (select ID from game where name=game_in),
        @userID := (select ID from user where username=username_in),
        @userRank := 0;
    if (select sort_order from game where id=@gameID) = 0 then
        set @userRank := (
            select rank
            from
                (
                    select
                        @rn:=@rn+1 as rank,
                        user_id
                    from
                        (
                            select
                                high_score,
                                game_id,
                                user_id
                            from ownership
                            where game_id=@gameID
                        ) t1,
                        (select @rn:=0) t2
                    order by high_score desc
                ) t
            where user_id=@userID
        );
    else
        set @userRank := (
            select rank
            from
                (
                    select
                        @rn:=@rn+1 as rank,
                        user_id
                    from
                        (
                            select
                                high_score,
                                game_id,
                                user_id
                            from ownership
                            where game_id=@gameID
                        ) t1,
                        (select @rn:=0) t2
                    order by high_score
                ) t
            where user_id=@userID
        );
    end if;
    set
        @n := (select count(*) from ownership where game_id=@gameID),
        @score_out := (
            select high_score
            from ownership
            where
                user_id=@userID and
                game_id=@gameID
        ),
        @prefix := (
            select prefix
            from
                score_format,
                game
            where
                game.score_format=score_format.id and
                game.id=@gameID
        ),
        @suffix := (
            select suffix
            from
                score_format,
                game
            where
                game.score_format=score_format.id and
                game.id=@gameID
        ),
        @rank_out := @userRank,
        @percent_out := @userRank*100/@n,
        string_out = concat(
            @prefix,
            @score_out,
            @suffix,
            " - ",
            @rank_out,
            " (Top ",
            @percent_out,
            "%)"
        );
end$$

DELIMITER ;

CREATE TABLE `achievement`
(
    `ID` int(11) NOT NULL,
    `title` text NOT NULL,
    `game_id` int(11) NOT NULL,
    `point_value` int(11) NOT NULL,
    `hidden` tinyint(1) NOT NULL,
    `descr_before` varchar(2000) NOT NULL DEFAULT '???',
    `descr_after` varchar(2000) NOT NULL DEFAULT '???',
    `icon_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

DELIMITER //
CREATE TRIGGER `achievement_before_insert` BEFORE INSERT ON `achievement` FOR EACH ROW
BEGIN
    DECLARE msg varchar(100);
    IF (NEW.point_value < 0 OR NEW.point_value > 100) THEN
        SET msg='Point value must be between 0 and 100';
        SIGNAL sqlstate '45000' SET message_text=msg;
    END IF;
    SET @totalPoints := (SELECT SUM(point_value) FROM achievement WHERE game_id=NEW.game_id);
    IF (@totalPoints + New.point_value > 1000) THEN
    	SET msg='A game can have maximum 1000 achievemnt points';
        SIGNAL sqlstate '45000' SET message_text=msg;
    END IF;
    SET @no = (SELECT COUNT(*) FROM achievement WHERE game_id=NEW.game_id);
    IF (@no + 1 > 100) THEN
    	SET msg='A game can have maximum 100 achievemnts';
        SIGNAL sqlstate '45000' SET message_text=msg;
    END IF;
END
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `achievement_before_update` BEFORE UPDATE ON `achievement` FOR EACH ROW
BEGIN
    DECLARE msg varchar(100);
    IF (NEW.point_value<0 OR NEW.point_value>100) THEN
        SET msg='Point value must be between 0 and 100';
        SIGNAL sqlstate '45000' SET message_text=msg;
    END IF;
	SET @totalPoints:=(SELECT SUM(point_value) FROM achievement WHERE game_id=NEW.game_id);
    IF (@totalPoints + NEW.point_value - OLD.point_value > 1000) THEN
        SET msg='A game can have maximum 1000 achievement points';
        SIGNAL sqlstate '45000' SET message_text=msg;
    END IF;
END
//
DELIMITER ;

CREATE TABLE `category`
(
    `ID` int(11) NOT NULL,
    `name` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

CREATE TABLE `friendship`
(
    `friend1` int(11) NOT NULL,
    `friend2` int(11) NOT NULL,
    `response` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `game`
(
    `ID` int(11) NOT NULL,
    `name` text NOT NULL,
    `description` text NOT NULL,
    `version` text NOT NULL,
    `age_rating` int(11) NOT NULL DEFAULT '0',
    `rating` float DEFAULT NULL,
    `icon_id` int(11) DEFAULT NULL,
    `url` text,
    `publisher_id` int(11) NOT NULL,
    `release_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `maximum_score` int(11) DEFAULT NULL,
    `minimum_score` int(11) DEFAULT NULL,
    `times_played` int(11) NOT NULL DEFAULT '0',
    `sort_order` tinyint(1) NOT NULL DEFAULT '0',
    `score_format` varchar(255) DEFAULT 'int'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

DELIMITER //
CREATE TRIGGER `game_after_insert` AFTER INSERT ON `game` FOR EACH ROW
BEGIN
    INSERT INTO leaderboard      (game_id, rank) VALUES (NEW.ID, 1), (NEW.ID, 2), (NEW.ID, 3), (NEW.ID, 4), (NEW.ID, 5), (NEW.ID, 6), (NEW.ID, 7), (NEW.ID, 8), (NEW.ID, 9), (NEW.ID, 10);
    INSERT INTO leaderboard_day  (game_id, rank) VALUES (NEW.ID, 1), (NEW.ID, 2), (NEW.ID, 3), (NEW.ID, 4), (NEW.ID, 5), (NEW.ID, 6), (NEW.ID, 7), (NEW.ID, 8), (NEW.ID, 9), (NEW.ID, 10);
    INSERT INTO leaderboard_week (game_id, rank) VALUES (NEW.ID, 1), (NEW.ID, 2), (NEW.ID, 3), (NEW.ID, 4), (NEW.ID, 5), (NEW.ID, 6), (NEW.ID, 7), (NEW.ID, 8), (NEW.ID, 9), (NEW.ID, 10);
    INSERT INTO rank (ID) VALUE (NEW.ID);
END
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `game_after_update` AFTER UPDATE ON `game` FOR EACH ROW
    IF (NEW.rating <> OLD.rating) THEN
    	UPDATE `rank`
        SET rank = (
            SELECT rnk
            FROM
                (
                    SELECT
                        @rn:=@rn+1 AS rnk,
                        rating,
                        ID
                    FROM
                        (
                            SELECT
                                rating,
                                ID
                            FROM game
                        ) t1,
                        (SELECT @rn:=0) t2
                    ORDER BY rating DESC
                ) tt
			WHERE rank.ID LIKE tt.ID
        );
        UPDATE `game_category_ranked`
        SET category_rank = (
			SELECT rn
            FROM (
				SELECT
                    game_ID,
                    category_ID,
                    rating,
                    @game :=
                        CASE WHEN @category <> category_id THEN
                            1
                        ELSE
                            @game+1
                        END AS rn,
				   @category := category_ID AS cat
				FROM
                    (SELECT @game:= 0) g,
                    (SELECT @category:= 0) c,
                    (
                        SELECT
                            game_ID,
                            category_ID,
                            rating
                        FROM
                            game_category_ranked,
                            game
                        WHERE game.ID = game_category_ranked.game_ID
                        ORDER BY
                            category_ID,
                            rating DESC
                    ) t
            ) tt3
			WHERE
                tt3.game_ID = game_category_ranked.game_ID AND
                tt3.category_ID = game_category_ranked.category_ID
        );
	END IF
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `game_before_insert` BEFORE INSERT ON `game` FOR EACH ROW
BEGIN
    DECLARE msg varchar(100);
    IF (NEW.age_rating<0 OR NEW.age_rating>25) THEN
        SET msg='Age rating must be between 0 and 25';
        SIGNAL sqlstate '45000' SET message_text=msg;
    END IF;
END
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `game_before_update` BEFORE UPDATE ON `game` FOR EACH ROW
BEGIN
    DECLARE msg varchar(100);
    IF (NEW.age_rating<0 OR NEW.age_rating>25) THEN
        SET msg='Age rating must be between 0 and 25';
        SIGNAL sqlstate '45000' SET message_text=msg;
    END IF;
END
//
DELIMITER ;

CREATE TABLE `game_category`
(
    `game_ID` int(11) NOT NULL,
    `category_ID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DELIMITER //
CREATE TRIGGER `gameCategory_after_insert` AFTER INSERT ON `game_category` FOR EACH ROW
BEGIN
    UPDATE `game_category_ranked`
    SET category_rank = (
        SELECT rn
        FROM
            (
                SELECT
                    game_ID,
                    category_ID,
                    rating,
                    @game :=
                        CASE WHEN @category <> category_id THEN
                            1
                        ELSE
                            @game+1
                        END AS rn,
                    @category:=category_ID AS cat
                FROM
                    (SELECT @game := 0) g,
                    (SELECT @category := 0) c,
                    (
                        SELECT
                            game_ID,
                            category_ID,
                            rating
                        FROM
                            game_category_ranked,
                            game
                        WHERE game.ID = game_category_ranked.game_ID
                        ORDER BY
                            category_ID,
                            rating DESC
                    ) t
            ) tt3
        WHERE
            tt3.game_ID = game_category_ranked.game_ID AND
            tt3.category_ID = game_category_ranked.category_ID
    );
END
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `gameCategory_before_insert` BEFORE INSERT ON `game_category` FOR EACH ROW
    INSERT INTO `game_category_ranked` (game_ID, category_ID)
	VALUES (NEW.game_ID, NEW.category_ID)
//
DELIMITER ;

CREATE TABLE `game_category_ranked`
(
    `game_ID` int(11) NOT NULL,
    `category_ID` int(11) NOT NULL,
    `category_rank` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `game_invite`
(
    `from_user` int(11) NOT NULL,
    `to_user` int(11) NOT NULL,
    `game` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `hot_list`
(
    `game_id` int(11) NOT NULL,
    `rank` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `image`
(
    `ID` int(11) NOT NULL,
    `URL` text NOT NULL,
    `PRESET` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

CREATE TABLE `leaderboard`
(
    `game_id` int(11) NOT NULL,
    `rank` int(11) NOT NULL,
    `user_id` int(11) DEFAULT NULL,
    `score` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `leaderboard_day`
(
    `game_id` int(11) NOT NULL,
    `rank` int(11) NOT NULL,
    `user_id` int(11) DEFAULT NULL,
    `score` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `leaderboard_week`
(
    `game_id` int(11) NOT NULL,
    `rank` int(11) NOT NULL,
    `user_id` int(11) DEFAULT NULL,
    `score` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `offensive_word`
(
    `word` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `ownership`
(
    `user_id` int(11) NOT NULL,
    `game_id` int(11) NOT NULL,
    `rating` float DEFAULT NULL,
    `comment` text NOT NULL,
    `last_played` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `version` text NOT NULL,
    `notification` tinyint(1) NOT NULL DEFAULT '0',
    `high_score` double DEFAULT NULL,
    `high_score_day` double DEFAULT NULL,
    `high_score_week` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DELIMITER //
CREATE TRIGGER `ownership_after_insert` AFTER INSERT ON `ownership` FOR EACH ROW
BEGIN
    SET @x := (
        SELECT COUNT(*)
        FROM ownership
        WHERE
            game_id = NEW.game_id AND
            rating IS NOT NULL
        LIMIT 1
    );
    IF (@x>9) THEN
        UPDATE game
        SET rating = (
            SELECT AVG(rating)
            FROM ownership
            WHERE game_id = NEW.game_id
        )
        WHERE game.id = NEW.game_id;
    ELSE
        UPDATE game SET rating = NULL WHERE game.id = NEW.game_id;
    END IF;
END
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `ownership_after_update` AFTER UPDATE ON `ownership` FOR EACH ROW
BEGIN
	SET @order = (SELECT sort_order FROM game where ID = NEW.game_id);
	IF (NEW.high_score <> OLD.high_score AND @order = 0) THEN
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 0, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 0, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 1;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 1, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 1, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 2;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 2, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 2, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 3;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 3, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 3, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 4;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 4, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 4, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 5;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 5, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 5, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 6;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 6, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 6, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 7;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 7, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 7, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 8;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 8, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 8, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 9;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 9, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 9, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 10;
    END IF;
	IF (NEW.high_score <> OLD.high_score AND @order = 0) THEN
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 0, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 0, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 1;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 1, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 1, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 2;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 2, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 2, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 3;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 3, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 3, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 4;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 4, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 4, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 5;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 5, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 5, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 6;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 6, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 6, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 7;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 7, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 7, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 8;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 8, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 8, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 9;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 9, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 9, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 10;
    END IF;
	IF (NEW.high_score <> OLD.high_score AND @order = 0) THEN
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 0, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 0, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 1;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 1, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 1, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 2;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 2, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 2, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 3;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 3, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 3, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 4;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 4, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 4, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 5;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 5, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 5, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 6;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 6, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 6, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 7;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 7, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 7, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 8;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 8, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 8, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 9;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 9, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score DESC LIMIT 9, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 10;
    END IF;
	IF (NEW.high_score <> OLD.high_score AND @order = 0) THEN
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 0, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 0, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 1;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 1, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 1, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 2;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 2, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 2, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 3;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 3, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 3, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 4;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 4, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 4, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 5;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 5, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 5, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 6;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 6, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 6, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 7;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 7, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 7, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 8;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 8, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 8, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 9;
        UPDATE leaderboard
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 9, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 9, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 10;
    END IF;
	IF (NEW.high_score <> OLD.high_score AND @order = 0) THEN
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 0, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 0, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 1;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 1, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 1, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 2;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 2, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 2, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 3;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 3, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 3, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 4;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 4, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 4, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 5;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 5, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 5, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 6;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 6, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 6, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 7;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 7, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 7, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 8;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 8, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 8, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 9;
        UPDATE leaderboard_day
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 9, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 9, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 10;
    END IF;
	IF (NEW.high_score <> OLD.high_score AND @order = 0) THEN
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 0, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 0, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 1;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 1, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 1, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 2;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 2, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 2, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 3;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 3, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 3, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 4;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 4, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 4, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 5;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 5, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 5, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 6;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 6, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 6, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 7;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 7, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 7, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 8;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 8, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 8, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 9;
        UPDATE leaderboard_week
        SET
            user_id = (SELECT user_id FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 9, 1),
            score = (SELECT high_score FROM ownership WHERE game_id=NEW.game_id ORDER BY high_score LIMIT 9, 1)
        WHERE
            game_id = NEW.game_id AND
            rank = 10;
    END IF;
    IF (NEW.last_played <> OLD.last_played) THEN
        UPDATE game
        SET times_played = times_played + 1
        WHERE NEW.game_id = ID;
    END IF;
    BEGIN
        SET @x := (
            SELECT COUNT(*)
            FROM ownership
            WHERE
                game_id = NEW.game_id AND
                rating IS NOT NULL
        );
        IF (@x>9) THEN
            UPDATE game
            SET rating = (SELECT AVG(rating) FROM ownership WHERE game_id=NEW.game_id)
            WHERE game.id=NEW.game_id;
        ELSE
            UPDATE game SET rating = NULL WHERE game.id=NEW.game_id;
        END IF;
    END;
END
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `ownership_before_insert` BEFORE INSERT ON `ownership` FOR EACH ROW
BEGIN
	IF (NEW.rating>5 OR NEW.rating<0) THEN
    	SET NEW.rating = NULL;
    END IF;
END
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `ownership_before_update` BEFORE UPDATE ON `ownership` FOR EACH ROW
BEGIN
	DECLARE msg varchar(100);
    DECLARE max_score int;
    DECLARE min_score int;
	SET @order = (SELECT sort_order FROM game where ID = NEW.game_id);
    SET max_score = (SELECT maximum_score FROM game WHERE ID=OLD.game_id),
    min_score = (SELECT minimum_score FROM game WHERE ID=OLD.game_id);
    IF (max_score IS NOT NULL AND NEW.high_score_day > max_score)
    THEN
        SET NEW.high_score_day = OLD.high_score_day;
        SET msg = 'This score is too high';
    ELSEIF (min_score IS NOT NULL AND NEW.high_score_day < min_score)
    THEN
        SET msg = 'This score is too low';
        SET NEW.high_score_day = OLD.high_score_day;
    ELSE
        IF (NEW.high_score_day > NEW.high_score AND @order = 0) THEN
            SET NEW.high_score = NEW.high_score_day;
        END IF;
        IF (NEW.high_score_day > NEW.high_score_week AND @order = 0) THEN
            SET NEW.high_score_week = NEW.high_score_day;
        END IF;
        IF (NEW.high_score_day < NEW.high_score AND @order = 1) THEN
            SET NEW.high_score = NEW.high_score_day;
        END IF;
        IF (NEW.high_score_day < NEW.high_score_week AND @order = 1) THEN
            SET NEW.high_score_week = NEW.high_score_day;
        END IF;
    END IF;
    IF (NEW.rating<0 OR NEW.rating>10) THEN
        SET msg = 'Rating value must be between 0 and 10';
    END IF;
    IF (NEW.rating>5 OR NEW.rating<0) THEN
    	SET msg = 'Rating has to be between 0 and 5';
    END IF;
    IF (msg IS NOT NULL) THEN
    	SIGNAL sqlstate '45000' SET message_text=msg;
    END IF;
END
//
DELIMITER ;

CREATE TABLE `publisher`
(
    `ID` int(11) NOT NULL,
    `Name` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

CREATE TABLE `rank`
(
    `ID` int(11) NOT NULL,
    `rank` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `score_format`
(
    `ID` varchar(255) NOT NULL,
    `prefix` text NOT NULL,
    `suffix` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user`
(
    `ID` int(11) NOT NULL,
    `username` varchar(255) NOT NULL,
    `first_name` text NOT NULL,
    `second_name` text NOT NULL,
    `email` varchar(255) NOT NULL,
    `password` text NOT NULL,
    `status` text NOT NULL,
    `creation_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_logged_in` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
    `logged_in` tinyint(1) NOT NULL DEFAULT '0',
    `avatar` int(11) DEFAULT NULL,
    `locked` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

DELIMITER //
CREATE TRIGGER `user_before_insert` BEFORE INSERT ON `user` FOR EACH ROW
BEGIN
    IF EXISTS
        (
            SELECT *
            FROM offensive_word
            WHERE NEW.username LIKE CONCAT('%',word,'%')
        ) THEN
        SET NEW.locked=1;
    ELSE
        SET NEW.locked=0;
    END IF;
END
//
DELIMITER ;
DELIMITER //
CREATE TRIGGER `user_before_update` BEFORE UPDATE ON `user` FOR EACH ROW
BEGIN
    IF EXISTS
    (
        SELECT *
        FROM offensive_word
        WHERE NEW.username LIKE CONCAT('%',word,'%')
    ) THEN
        SET NEW.locked=1;
    ELSE
        SET NEW.locked=0;
    END IF;
END
//
DELIMITER ;

CREATE TABLE `user_achievement`
(
    `user_id` int(11) NOT NULL,
    `achievement_id` int(11) NOT NULL,
    `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DELIMITER //
CREATE TRIGGER `userAchievement_before_insert` BEFORE INSERT ON `user_achievement` FOR EACH ROW
BEGIN
	DECLARE msg varchar(100);
    set @gameID = (select game_id from achievement where ID = new.achievement_id);
    set @own = (
        select count(*)
        from ownership
        where
            user_id = NEW.user_id and
            game_id = @gameID
    );
    IF (@own <> 1) THEN
        SET msg='Age rating must be between 0 and 25';
        SIGNAL sqlstate '45000' SET message_text = msg;
    END IF;
END
//
DELIMITER ;

CREATE VIEW `game_ranked` AS
    select
        `game`.`ID` AS `ID`,
        `game`.`name` AS `name`,
        `game`.`description` AS `description`,
        `game`.`version` AS `version`,
        `game`.`age_rating` AS `age_rating`,
        `game`.`rating` AS `rating`,
        `game`.`icon_id` AS `icon_id`,
        `game`.`url` AS `url`,
        `game`.`publisher_id` AS `publisher_id`,
        `game`.`release_date` AS `release_date`,
        `game`.`maximum_score` AS `maximum_score`,
        `game`.`minimum_score` AS `minimum_score`,
        `game`.`times_played` AS `times_played`,
        `game`.`sort_order` AS `sort_order`,
        `game`.`score_format` AS `score_format`,
        `rank`.`rank` AS `rank`
    from
        `game` join `rank` on(`game`.`ID` = `rank`.`ID`);

CREATE VIEW `top_10_games_per_category` AS
    select
        category.name AS category,
        game.name AS game,
        game_category_ranked.category_rank AS rank
    from
        game,
        category,
        game_category_ranked
    where
        game_category_ranked.category_rank <= 10 and
        game.ID = game_category_ranked.game_ID and
        category.ID = game_category_ranked.category_ID
    order by
        game_category_ranked.category_ID,
        game_category_ranked.category_rank;

ALTER TABLE `achievement`
    ADD PRIMARY KEY (`ID`),
     ADD KEY `icon_id` (`icon_id`),
     ADD KEY `game_id` (`game_id`);

ALTER TABLE `category`
    ADD PRIMARY KEY (`ID`),
    ADD UNIQUE KEY `name` (`name`);


ALTER TABLE `friendship`
    ADD PRIMARY KEY (`friend1`,`friend2`),
    ADD KEY `friend2` (`friend2`);

ALTER TABLE `game`
    ADD PRIMARY KEY (`ID`),
     ADD KEY `icon_id` (`icon_id`),
     ADD KEY `publisher_id` (`publisher_id`),
     ADD KEY `score_format` (`score_format`);

ALTER TABLE `game_category`
    ADD PRIMARY KEY (`game_ID`,`category_ID`),
    ADD KEY `category_ID` (`category_ID`);

ALTER TABLE `game_category_ranked`
    ADD PRIMARY KEY (`game_ID`,`category_ID`),
    ADD KEY `category_ID` (`category_ID`);

ALTER TABLE `game_invite`
    ADD PRIMARY KEY (`from_user`,`to_user`,`game`),
    ADD KEY `to_user` (`to_user`),
    ADD KEY `game` (`game`);

ALTER TABLE `hot_list`
    ADD PRIMARY KEY (`rank`),
    ADD UNIQUE KEY `game_id` (`game_id`);

ALTER TABLE `image`
    ADD PRIMARY KEY (`ID`);

ALTER TABLE `leaderboard`
    ADD PRIMARY KEY (`game_id`,`rank`),
    ADD KEY `user_id` (`user_id`);

ALTER TABLE `leaderboard_day`
    ADD PRIMARY KEY (`game_id`,`rank`),
    ADD KEY `user_id` (`user_id`);

ALTER TABLE `leaderboard_week`
    ADD PRIMARY KEY (`game_id`,`rank`),
    ADD KEY `user_id` (`user_id`);

ALTER TABLE `offensive_word`
    ADD PRIMARY KEY (`word`);

ALTER TABLE `ownership`
    ADD PRIMARY KEY (`user_id`,`game_id`),
    ADD KEY `game_id` (`game_id`);

ALTER TABLE `publisher`
    ADD PRIMARY KEY (`ID`);

ALTER TABLE `rank`
    ADD PRIMARY KEY (`ID`);

ALTER TABLE `score_format`
    ADD PRIMARY KEY (`ID`);

ALTER TABLE `user`
    ADD PRIMARY KEY (`ID`),
    ADD UNIQUE KEY `username` (`username`),
    ADD UNIQUE KEY `email` (`email`),
    ADD KEY `avatar` (`avatar`);

ALTER TABLE `user_achievement`
    ADD PRIMARY KEY (`user_id`,`achievement_id`),
    ADD KEY `achievement_id` (`achievement_id`);

ALTER TABLE `achievement`
    ADD CONSTRAINT `achievement_ibfk_1` FOREIGN KEY (`icon_id`) REFERENCES `image` (`ID`) ON DELETE SET NULL ON UPDATE CASCADE,
    ADD CONSTRAINT `achievement_ibfk_2` FOREIGN KEY (`game_id`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `friendship`
    ADD CONSTRAINT `friendship_ibfk_1` FOREIGN KEY (`friend1`) REFERENCES `user` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `friendship_ibfk_2` FOREIGN KEY (`friend2`) REFERENCES `user` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `game`
    ADD CONSTRAINT `game_ibfk_1` FOREIGN KEY (`icon_id`) REFERENCES `image` (`ID`) ON DELETE SET NULL ON UPDATE CASCADE,
    ADD CONSTRAINT `game_ibfk_2` FOREIGN KEY (`publisher_id`) REFERENCES `publisher` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `game_ibfk_3` FOREIGN KEY (`score_format`) REFERENCES `score_format` (`ID`) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `game_category`
    ADD CONSTRAINT `game_category_ibfk_2` FOREIGN KEY (`category_ID`) REFERENCES `category` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `game_category_ibfk_1` FOREIGN KEY (`game_ID`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `game_category_ranked`
    ADD CONSTRAINT `game_category_ranked_ibfk_1` FOREIGN KEY (`game_ID`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `game_category_ranked_ibfk_2` FOREIGN KEY (`category_ID`) REFERENCES `category` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `game_invite`
    ADD CONSTRAINT `game_invite_ibfk_3` FOREIGN KEY (`game`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `game_invite_ibfk_1` FOREIGN KEY (`from_user`) REFERENCES `user` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `game_invite_ibfk_2` FOREIGN KEY (`to_user`) REFERENCES `user` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `hot_list`
    ADD CONSTRAINT `hot_list_ibfk_1` FOREIGN KEY (`game_id`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `leaderboard`
    ADD CONSTRAINT `leaderboard_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`ID`) ON DELETE SET NULL ON UPDATE SET NULL,
    ADD CONSTRAINT `leaderboard_ibfk_1` FOREIGN KEY (`game_id`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `leaderboard_day`
    ADD CONSTRAINT `leaderboard_day_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`ID`) ON DELETE SET NULL ON UPDATE SET NULL,
    ADD CONSTRAINT `leaderboard_day_ibfk_1` FOREIGN KEY (`game_id`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `leaderboard_week`
    ADD CONSTRAINT `leaderboard_week_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`ID`) ON DELETE SET NULL ON UPDATE SET NULL,
    ADD CONSTRAINT `leaderboard_week_ibfk_1` FOREIGN KEY (`game_id`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `ownership`
    ADD CONSTRAINT `ownership_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `ownership_ibfk_2` FOREIGN KEY (`game_id`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `rank`
    ADD CONSTRAINT `rank_ibfk_1` FOREIGN KEY (`ID`) REFERENCES `game` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `user`
    ADD CONSTRAINT `user_ibfk_1` FOREIGN KEY (`avatar`) REFERENCES `image` (`ID`) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `user_achievement`
    ADD CONSTRAINT `user_achievement_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `user_achievement_ibfk_2` FOREIGN KEY (`achievement_id`) REFERENCES `achievement` (`ID`) ON DELETE CASCADE ON UPDATE CASCADE;

DELIMITER $$
CREATE EVENT `hot_list_update` ON SCHEDULE EVERY 1 WEEK STARTS '2014-05-12 00:00:00' ON COMPLETION PRESERVE ENABLE DO BEGIN
	TRUNCATE TABLE hot_list;

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 0, 1), 1);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 1, 1), 2);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 2, 1), 3);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 3, 1), 4);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 4, 1), 5);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 5, 1), 6);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 6, 1), 7);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 7, 1), 8);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 8, 1), 9);

	INSERT INTO hot_list (game_id, rank)
	VALUES ((SELECT ID FROM game ORDER BY times_played DESC LIMIT 9, 1), 10);

    UPDATE game SET times_played = 0;
END$$

CREATE EVENT `score_reset_weekly` ON SCHEDULE EVERY 1 WEEK STARTS '2014-05-12 00:00:00' ON COMPLETION PRESERVE ENABLE DO BEGIN
	UPDATE leaderboard_week SET user_id=NULL, score=NULL;
    UPDATE ownership SET high_score_week=NULL;
END$$

CREATE EVENT `score_reset_daily` ON SCHEDULE EVERY 1 DAY STARTS '2014-05-12 00:00:00' ON COMPLETION PRESERVE ENABLE DO BEGIN
	UPDATE leaderboard_day SET user_id=NULL, score=NULL;
    UPDATE ownership SET high_score_day=NULL;
END$$

DELIMITER ;
