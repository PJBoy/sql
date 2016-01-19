-- 1. What year was the film 'Fight Club' made?
select yr
from shared.movie
where title='Fight Club';

-- 2. What is the score of the film 'Vertigo'?
select score
from shared.movie
where title='Vertigo';

-- 3. Who starred in the film '12 Angry Men'?
select name
from
    shared.movie,
    shared.actor,
    shared.casting
where
    movieid=movie.id and
    actorid=actor.id and
    ord=1 and
    title='12 Angry Men';

-- 4. List the title and scores (in descending order) for the films directed by Joel Coen
select
    title,
    score
from
    shared.movie,
    shared.actor
where
    director=actor.id and
    name='Joel Coen'
order by score desc;

-- 5. List the titles of other films starring actors who appeared in the film 'Alien'
select movieOther.title
from
    shared.movie movieAlien,
    shared.movie movieOther,
    shared.casting castingAlien,
    shared.casting castingOther
where
    castingAlien.actorid=castingOther.actorid and
    castingAlien.movieid=movieAlien.id and
    castingOther.movieid=movieOther.id and
    castingOther.ord=1 and
    movieAlien.title='Alien' and
    movieOther.title<>'Alien';

-- 6. Give the title and score of the best film of the final year of the database
select *
from
    (
        select
            title,
            score
        from shared.movie
        order by
            yr desc,
            score desc
    )
where rownum<=1;

-- 7. Give the title of the film with 'John' in the title, which had actor(s) with first name 'John'
select distinct title
from
    shared.movie,
    shared.actor,
    shared.casting
where
    movieid=movie.id and
    actorid=actor.id and
    name like 'John %' and
    (
        title='John' or
        title like 'John %' or
        title like '% John' or 
        title like '% John %'
    );

-- 8. List title, year and score for the films starring Kurt Russell and directed by John Carpenter
select
    title,
    yr,
    score
from
    shared.movie,
    shared.actor d,
    shared.actor s,
    shared.casting
where
    movieid=movie.id and
    actorid=s.id and
    director=d.id and
    d.name='John Carpenter' and
    ord=1 and
    s.name='Kurt Russell';

-- 9. List the title, year and score for the best five films that Humphrey Bogart starred in
select *
from
    (
        select
            title,
            yr,
            score
        from
            shared.movie,
            shared.actor,
            shared.casting
        where
            actorid=actor.id and
            movieid=movie.id
            and ord=1
            and name='Humphrey Bogart'
        order by score desc
    )
where rownum<=5;

-- 10. What’s the film that starred Jack Nicholson and its director also directed a film starring Johnny Depp?
select title
from
    shared.movie,
    shared.actor,
    shared.casting
where
    actorid=actor.id and
    movieid=movie.id and
    ord=1 and
    name='Jack Nicholson' and
    director in
    (
        select director
        from
            shared.movie,
            shared.actor,
            shared.casting
        where
            actorid=actor.id and
            movieid=movie.id and
            ord=1 and
            name='Johnny Depp'
    );

-- 11. List the actors in 'The Godfather', who weren’t in 'The Godfather: Part II'
(
    select name
    from
        shared.movie,
        shared.actor,
        shared.casting
    where
        actorid=actor.id and
        movieid=movie.id and
        title='Godfather, The'
)
minus
(
    select name
    from
        shared.movie,
        shared.actor,
        shared.casting
    where
        actorid=actor.id and
        movieid=movie.id and
        title='Godfather: Part II, The'
);

-- 12. List the title and score of the best and worst films in which Dennis Hopper appeared
(
    select *
    from
    (
        select
            title,
            score
        from
            shared.movie,
            shared.actor,
            shared.casting
        where
            actorid=actor.id and
            movieid=movie.id and
            name='Dennis Hopper'
        order by score desc
    )
    where rownum<=1
)
union
(
    select *
    from
        (
            select
                title,
                score
            from
                shared.movie,
                shared.actor,
                shared.casting
            where
                actorid=actor.id and
                movieid=movie.id and
                name='Dennis Hopper'
            order by score asc
        )
    where rownum<=1
);

-- 13. In which year did Bruce Willis make most films (show the year and number of films)
select *
from
    (
        select
            count(*) as n,
            yr
        from
            shared.movie,
            shared.actor,
            shared.casting
        where
            movieid=movie.id and
            actorid=actor.id and
            name='Bruce Willis'
        group by yr
        order by n desc
    )
    where rownum <= 1;

-- 14. List the directors, who have starred in films they directed along with the number of those films each has starred in and the year the earliest was made (in descending order of year)
select *
from
    (
        select
            name,
            min(yr) as year,
            count(director) as n
        from
            shared.movie,
            shared.actor,
            shared.casting
        where
            actorid=actor.id and
            movieid=movie.id and
            actorid=director and
            ord=1
        group by
            director,
            name
    )
    order by year desc;

-- 15. List the names of actors who have appeared in at least three films directed by Alfred Hitchcock along with the number of those films each has starred in (in descending order of number of films)
with directed as
    (
        select movie.id
        from
            shared.movie,
            shared.actor
        where
            actor.id=director and
            name='Alfred Hitchcock'
    )
select
    q1.name,
    nvl(q2.n,0) as n
from
    (
        select name
        from
            shared.actor,
            shared.casting,
            directed
        where
            actorid=actor.id and
            movieid=directed.id
        group by name
        having count(actorid) >= 3
    ) q1
    left outer join
    (
        select
            name,
            count(actorid) as n
        from
            shared.actor,
            shared.casting,
            directed
        where
            actorid=actor.id and
            movieid=directed.id and
            ord=1
        group by name
    ) q2
    on q1.name=q2.name
order by n desc;

-- 16. List the title, director’s name, co-star (ord = 2), year and score (in descending order of score) for the five best films starring Robert De Niro
select *
from
    (
        select
            title,
            yr,
            score,
            actorDirector.name as director,
            actorCostar.name as costar
        from
            shared.movie,
            shared.actor actorStar,
            shared.actor actorCostar,
            shared.actor actorDirector,
            shared.casting castingStar,
            shared.casting castingCostar
        where
            castingStar.movieid=movie.id and
            castingStar.actorid=actorStar.id and
            castingCostar.actorid=actorCostar.id and
            castingCostar.movieid=movie.id and
            director=actorDirector.id and
            castingStar.ord=1 and
            castingCostar.ord=2 and
            actorStar.name='Robert De Niro'
        order by score desc
    )
where rownum <= 5;

-- 17. Find the actor(s) who has appeared in most films, but has never starred in one
with nonStars as
    (
        select *
        from
        (
            shared.casting
            natural join
            (
                (
                    select actorid
                    from shared.casting
                )
                minus
                (
                    select actorid
                    from shared.casting
                    where ord=1
                )
            )
        )
    )
select
    name,
    count(*) as n
from
    shared.actor,
    nonStars
where actorid=actor.id
group by name
having count(*) =
    (
        select *
        from
            (
                select count(*) as n
                from nonStars
                group by actorid
                order by n desc
            )
        where rownum<=1
    );

-- 18. List the five actors with the longest careers (the time between their first and last film). For each one give their name, and the length of their career (in descending order of career length)
select *
from
    (
        select
            name,
            max(yr)-min(yr) as length
        from
            shared.movie,
            shared.actor,
            shared.casting
        where
            movieid=movie.id and
            actorid=actor.id
        group by name
        order by length desc
    )
where rownum<=5;

-- 19. List the 10 best directors (use the average score of their films to determine who is best) in descending order along with the number of films they’ve made and the average score for their films. Only consider directors who have made at least five films
select *
from
    (
        select
            name,
            count(*) as n,
            avg(score) as average
        from
            shared.movie,
            shared.actor
        where actor.id=director
        group by name
        having count(*)>=5
        order by average desc
    )
where rownum<=10;

-- 20. List the decades from the 30s (1930-39) to the 90s (1990-99) and for each of those decades show the average film score, the best film and the actor who starred in most films
-- The stars of each decade
with
    stars as
        (
            select
                floor(yr/10)*10 as decade,
                actorid
            from
                shared.movie,
                shared.casting
            where
                movieid = movie.id and
                yr >= 1930 and
                yr < 2000 and
                ord = 1
        ),
-- The scores of each decade
    decades as
        (
            select
                floor(yr/10)*10 as decade,
                score
            from shared.movie
            where
                yr >= 1930 and
                yr < 2000
        ),
-- The maximum scores of each decade
    maxScores as
        (
            select
                decade,
                max(score) as max
            from
                (
                    select
                        floor(yr/10)*10 as decade,
                        score
                    from shared.movie
                    where
                        yr >= 1930 and
                        yr < 2000
                )
            group by decade
        ),
-- The number of films starred in by each star of each decade
    numStars as
        (
            select
                decade,
                actorid,
                count(*) as n
            from stars
            group by
                decade,
                actorid
        )
select
    averageScore.decade,
    average,
    best,
    name
from
    -- Average scores
    (
        select
            decade,
            avg(score) as average
        from decades
        group by decade
    ) averageScore,
    -- Best movies
    (
        select
            decade,
            title as best
        from
            shared.movie,
            maxScores
        where
            score = max and
            floor(yr/10)*10 = decade
    ) bestMovie,
    -- Most starred actor
    (
        select
            nStarred.decade,
            name
        from
            shared.actor,
            numStars,
            -- Number of movies starred in by most starred actor
            (
                select
                    decade,
                    max(n) as max
                from numStars
                group by decade
            ) nStarred
        where
            actor.id = actorid and
            nStarred.decade = numStars.decade and
            n = max
    ) mostStarred
where
    averageScore.decade = bestMovie.decade and
    averageScore.decade = mostStarred.decade
order by decade desc;
