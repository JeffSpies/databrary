package macros

import scala.concurrent._
import Future.{successful,failed}
import duration.Duration
import scala.util.{Try,Success,Failure}
import scala.util.control.{Exception,NonFatal}
import Exception.Catch
import scala.collection.{GenTraversableOnce,generic}
import scala.language.higherKinds

/** Various utilities for dealing with Futures.
  * All operations are serial (as opposed to their counterparts on Future, which tend to be parallel.
  */
object async {
  val void : Future[Unit] = successful(())
  def apply[A](a : A) : Future[A] = successful(a)

  /** Transform a Catch to a Future. */
  private def apply[T](c : Catch[T]) : Catch[Future[T]] =
    c.withApply(failed)
  def catching[T](exceptions : Class[_]*) : Catch[Future[T]] =
    apply(Exception.catching(exceptions : _*))
  /** Wrap any thrown exception in a future. */
  def Try[A](a : => A) : Future[A] =
    /* this is stupid: Promise lacks the direct constructor */
    scala.util.Try(a) match {
      case Success(a) => successful(a)
      case Failure(a) => failed(a)
    }

  implicit class Async[A](a : A) {
    def async : Future[A] = successful(a)
  }

  private def ss[A](a : A) : Future[Option[A]] = successful(Some(a))

  implicit class AsyncTraversableOnce[A](l : TraversableOnce[A]) extends Async[TraversableOnce[A]](l) {
    /** Evaluate each of the futures, serially. */
    def foreachAsync[R](f : A => Future[_], r : => R = ())(implicit context : ExecutionContext) : Future[R] = {
      l.foldLeft[Future[Any]](void) { (r, a) =>
	r.flatMap(_ => f(a))
      }.map(_ => r)
    }
  }

  implicit class AsyncOption[A](o : Option[A]) extends AsyncTraversableOnce[A](o) {
    /** Unwrap and map an Option into a Future Option. */
    def flatMapAsync[B](f : A => Future[Option[B]]) : Future[Option[B]] =
      o.fold[Future[Option[B]]](successful(None))(f(_))
    /** Unwrap and map an Option into a Future. */
    def mapAsync[B](f : A => Future[B])(implicit context : ExecutionContext) : Future[Option[B]] =
      flatMapAsync[B](f(_).map(Some(_)))
    def orElseAsync[B >: A](b : => Future[Option[B]]) : Future[Option[B]] =
      if (o.isEmpty) b else successful(o)
    def getOrElseAsync[B >: A](b : => Future[B]) : Future[B] =
      o.fold(b)(successful(_))
    def filterAsync(f : A => Future[Boolean])(implicit context : ExecutionContext) : Future[Option[A]] =
      flatMapAsync[A](a => f(a).map { case false => None ; case true => Some(a) })
  }

  implicit class AsyncSeq[A](l : Seq[A]) extends AsyncTraversableOnce[A](l) {
    /** Evaluate each of the futures, serially left-to-right, and produce a list of the results. */
    def mapAsync[B, R](f : A => Future[B])(implicit bf : generic.CanBuildFrom[Seq[A], B, R], context : ExecutionContext) : Future[R] = {
      val b = bf()
      foreachAsync[R](f(_).andThen { case Success(a) => b += a }, b.result)
    }
    def flatMapAsync[B, R](f : A => Future[Seq[B]])(implicit bf : generic.CanBuildFrom[Seq[A], B, R], context : ExecutionContext) : Future[R] = {
      val b = bf()
      foreachAsync[R](f(_).andThen { case Success(a) => b ++= a }, b.result)
    }
  }

  implicit class AsyncMap[K, A](m : Map[K, A]) extends Async[Map[K, A]](m) {
    /** Evaluate each of the futures in the Map in an arbitrary order and produce a collection of the results.
      * This is not as efficient as it could be due to a lack of foldMap/mapAccum-type functions. */
    def mapValuesAsync[B, R](f : A => Future[B])(implicit bf : generic.CanBuildFrom[Map[K, A], (K, B), R], context : ExecutionContext) : Future[R] = {
      val b = bf()
      def madd(x : AnyRef) : Future[Any] = x match {
	case f : Future[Any] => f
	case (k : K, a : A) => f(a).map(v => b.+=((k, v)))
      }
      madd(m.fold[AnyRef](void) { (l, r) =>
	madd(l).flatMap(_ => madd(r))
      }).map(_ => b.result)
    }
  }

  private def peek[A](a : Future[A]) : Option[A] = a.value.map(_.get)
  /** Unsafely retrieve the value of an already evaluated Future. */
  private final class UnevaluatedFutureException extends RuntimeException("Future has not yet completed")
  private def get[A](a : Future[A]) : A = a.value match {
    case Some(v) => v.get
    case None => throw new UnevaluatedFutureException /* checked explicitly to shorten stack trace */
  }
}
